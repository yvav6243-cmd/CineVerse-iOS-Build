import Foundation

public protocol ITunesCatalogServiceProtocol: Sendable {
    func topMovies(genreID: Int?, limit: Int) async throws -> [MediaItem]
    func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem]
    func searchMovies(query: String, limit: Int) async throws -> [MediaItem]
    func lookupDetails(providerID: String) async throws -> MediaItem?
    func findPlayablePreviewURL(title: String, originalTitle: String, isEpisodic: Bool, episodeNumber: Int?) async -> URL?
    func openCinemaShowcase() -> [MediaItem]
    func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)?
}

public final class ITunesCatalogService: ITunesCatalogServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://itunes.apple.com")

    public static let genreIDsByName: [(id: Int, name: String)] = [
        (4401, "Action & Adventure"),
        (4404, "Comedy"),
        (4405, "Documentary"),
        (4406, "Drama"),
        (4408, "Horror"),
        (4410, "Kids & Family"),
        (4412, "Romance"),
        (4413, "Sci-Fi & Fantasy"),
        (4416, "Thriller"),
        (4431, "Anime"),
        (4403, "Classics")
    ]

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func topMovies(genreID: Int? = nil, limit: Int = 60) async throws -> [MediaItem] {
        try await fetchChartMovies(genreID: genreID, limit: limit, forcedProjectType: nil)
    }

    private func fetchChartMovies(
        genreID: Int?,
        limit: Int,
        forcedProjectType: MediaProjectType?
    ) async throws -> [MediaItem] {
        let clampedLimit = min(max(limit, 10), 100)
        let path: String
        if let genreID {
            path = "us/rss/topmovies/limit=\(clampedLimit)/genre=\(genreID)/json"
        } else {
            path = "us/rss/topmovies/limit=\(clampedLimit)/json"
        }

        let endpoint = Endpoint(baseURL: baseURL, path: path, timeoutInterval: 15)
        let root = try await httpClient.send(endpoint, as: ITunesRSSRootDTO.self)
        let entries = root.feed?.entry ?? []
        return entries.enumerated().compactMap { index, entry in
            mapRSSEntry(
                entry,
                rankIndex: index,
                forcedGenreID: genreID,
                forcedProjectType: forcedProjectType
            )
        }
    }

    public func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem] {
        switch category {
        case .cartoonMovie:
            guard page == 1 else { return [] }
            let openAnimated = openCinemaShowcase().filter { $0.projectType == .cartoonMovie }
            let charts = try await fetchChartMovies(genreID: 4410, limit: 80, forcedProjectType: .cartoonMovie)
            return openAnimated + charts
        case .documentary:
            guard page == 1 else { return [] }
            let openDocs = openCinemaShowcase().filter { $0.projectType == .documentary }
            let charts = try await fetchChartMovies(genreID: 4405, limit: 80, forcedProjectType: .documentary)
            return openDocs + charts
        case .animeMovie:
            return page == 1 ? try await fetchChartMovies(genreID: 4431, limit: 60, forcedProjectType: .animeMovie) : []
        case .drama:
            guard page == 1 else { return [] }
            return try await fetchChartMovies(genreID: 4406, limit: 80, forcedProjectType: .drama)
        case .special:
            return page == 1 ? openCinemaShowcase() : []
        case .movie:
            let genrePages: [Int?] = [nil, 4401, 4413, 4404, 4416, 4408, 4412, 4403]
            guard page >= 1 && page <= genrePages.count else { return [] }
            let fetched = try await topMovies(genreID: genrePages[page - 1], limit: 80)
            if page == 1 {
                let openMovies = openCinemaShowcase().filter { $0.projectType == .movie }
                return openMovies + fetched
            }
            return fetched
        default:
            return []
        }
    }

    public func searchMovies(query: String, limit: Int = 35) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let ep = Endpoint(
            baseURL: baseURL,
            path: "search",
            queryItems: [
                URLQueryItem(name: "term", value: trimmed),
                URLQueryItem(name: "country", value: "US"),
                URLQueryItem(name: "limit", value: String(min(limit, 50)))
            ],
            timeoutInterval: 12
        )
        let res = try await httpClient.send(ep, as: ITunesSearchResponseDTO.self)
        let movieMatches = (res.results ?? [])
            .filter { $0.kind == "feature-movie" }
            .enumerated()
            .compactMap { idx, dto in mapTrack(dto, rankIndex: idx) }

        let openMatches = openCinemaShowcase().filter {
            $0.localizedTitle.localizedCaseInsensitiveContains(trimmed)
                || $0.originalTitle.localizedCaseInsensitiveContains(trimmed)
        }
        return openMatches + movieMatches
    }

    public func lookupDetails(providerID: String) async throws -> MediaItem? {
        if providerID.hasPrefix("open-") {
            return openCinemaShowcase().first { $0.id == "opencinema:movie:\(providerID)" }
        }
        let cleanID = providerID.replacingOccurrences(of: "itunes-", with: "")
        let ep = Endpoint(
            baseURL: baseURL,
            path: "lookup",
            queryItems: [
                URLQueryItem(name: "id", value: cleanID),
                URLQueryItem(name: "country", value: "US")
            ],
            timeoutInterval: 12
        )
        let res = try await httpClient.send(ep, as: ITunesSearchResponseDTO.self)
        guard let track = res.results?.first(where: { $0.trackId != nil }) else {
            return nil
        }
        var mapped = mapTrack(track, rankIndex: 0)
        // Attach similar movies from matching genre
        if let genreName = track.primaryGenreName,
           let matchedGenreID = Self.genreIDsByName.first(where: { $0.name.lowercased() == genreName.lowercased() })?.id,
           let related = try? await topMovies(genreID: matchedGenreID, limit: 12) {
            mapped?.similarProjectIDs = related.filter { $0.id != mapped?.id }.prefix(10).map(\.id)
        }
        return mapped
    }

    public func findPlayablePreviewURL(
        title: String,
        originalTitle: String,
        isEpisodic: Bool,
        episodeNumber: Int?
    ) async -> URL? {
        let candidates = [title, originalTitle].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for term in candidates {
            let ep = Endpoint(
                baseURL: baseURL,
                path: "search",
                queryItems: [
                    URLQueryItem(name: "term", value: term),
                    URLQueryItem(name: "country", value: "US"),
                    URLQueryItem(name: "limit", value: "12")
                ],
                timeoutInterval: 8
            )
            guard let res = try? await httpClient.send(ep, as: ITunesSearchResponseDTO.self),
                  let results = res.results else {
                continue
            }

            let targetKind = isEpisodic ? "tv-episode" : "feature-movie"
            let normalizedTarget = term.normalizedForComparison

            // Prefer exact kind & title match
            if let exact = results.first(where: { dto in
                guard dto.kind == targetKind,
                      let p = dto.previewUrl, p.hasPrefix("https://") else { return false }
                if isEpisodic, let epNum = episodeNumber, let trackNum = dto.trackNumber, trackNum == epNum {
                    return true
                }
                let tName = (dto.trackName ?? dto.collectionName ?? "").normalizedForComparison
                let cName = (dto.collectionName ?? "").normalizedForComparison
                return tName.contains(normalizedTarget) || normalizedTarget.contains(tName)
                    || (!cName.isEmpty && (cName.contains(normalizedTarget) || normalizedTarget.contains(cName)))
            }), let urlStr = exact.previewUrl, let url = URL(string: urlStr) {
                return url
            }

            // Fallback to any video track with matching title & valid https previewUrl
            if let anyMatch = results.first(where: { dto in
                guard (dto.kind == "feature-movie" || dto.kind == "tv-episode"),
                      let p = dto.previewUrl, p.hasPrefix("https://") else { return false }
                let combined = "\(dto.trackName ?? "") \(dto.collectionName ?? "")".normalizedForComparison
                return combined.contains(normalizedTarget) || normalizedTarget.contains(combined)
            }), let urlStr = anyMatch.previewUrl, let url = URL(string: urlStr) {
                return url
            }
        }
        return nil
    }

    public func openCinemaShowcase() -> [MediaItem] {
        [
            MediaItem(
                id: "opencinema:movie:open-tears-of-steel",
                externalIDs: [.openCinema: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "Tears of Steel (Open Cinema HD)",
                originalTitle: "Tears of Steel",
                synopsis: "In a dystopian future Amsterdam, a group of warriors and scientists gather at the Oude Kerk to stage a desperate mission to save the world from destructive robots. Full open-movie stream with adaptive HLS qualities and multi-language subtitles.",
                releaseYear: 2012,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "13+",
                genres: ["Sci-Fi", "Action"],
                durationMinutes: 12,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.8),
                popularityScore: 950,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Tos-poster.png/600px-Tos-poster.png"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Tos-poster.png/800px-Tos-poster.png"),
                director: "Ian Hubert (Blender Institute)"
            ),
            MediaItem(
                id: "opencinema:movie:open-big-buck-bunny",
                externalIDs: [.openCinema: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Big Buck Bunny (Full Animated Film)",
                originalTitle: "Big Buck Bunny",
                synopsis: "A gentle giant rabbit's peaceful morning in the sunlit forest is interrupted by three mischievous woodland bullies—until he devises an unforgettable comical payback. Full 1080p adaptive HLS open animated film.",
                releaseYear: 2008,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "6+",
                genres: ["Animation", "Comedy", "Family"],
                durationMinutes: 10,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.6),
                popularityScore: 920,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/600px-Big_buck_bunny_poster_big.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/800px-Big_buck_bunny_poster_big.jpg"),
                director: "Sacha Goedegebure (Blender Foundation)"
            ),
            MediaItem(
                id: "opencinema:movie:open-apple-dolby-showcase",
                externalIDs: [.openCinema: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"],
                primarySource: .openCinema,
                projectType: .documentary,
                localizedTitle: "Cinema Mastering Showcase (Multi-Audio HLS)",
                originalTitle: "Apple Cinema Mastering Showcase",
                synopsis: "High-dynamic-range adaptive HLS cinema stream featuring multiple audio tracks and embedded subtitles for instant testing of CineVerse's pre-watch voiceover, quality, and subtitle selector.",
                releaseYear: 2024,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Documentary", "Sci-Fi"],
                durationMinutes: 5,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 8.4),
                popularityScore: 910,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/600px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/1024px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                director: "Cinema Engineering Team"
            )
        ]
    }

    public func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)? {
        let fullID = providerID.hasPrefix("opencinema:") ? providerID : "opencinema:movie:\(providerID)"
        guard let match = openCinemaShowcase().first(where: { $0.id == fullID }),
              let raw = match.externalIDs[.openCinema],
              let url = URL(string: raw) else {
            return nil
        }
        let fmt: VideoStreamFormat = url.pathExtension.lowercased() == "m3u8" || raw.contains(".m3u8") ? .hls : .mp4
        return (url, fmt, "CineVerse Open Cinema (Full HD Stream)")
    }

    // MARK: - Private Mapping Helpers

    private func mapRSSEntry(
        _ entry: ITunesRSSEntryDTO,
        rankIndex: Int,
        forcedGenreID: Int?,
        forcedProjectType: MediaProjectType?
    ) -> MediaItem? {
        guard let rawID = entry.id?.attributes?.imId?.nilIfEmpty,
              let title = entry.name?.label?.nilIfEmpty else {
            return nil
        }

        let rawArtwork = entry.images?.last?.label
        let posterURL = highResArtworkURL(from: rawArtwork, dimensions: "600x900bb.jpg")
        let backdropURL = highResArtworkURL(from: rawArtwork, dimensions: "1000x1500bb.jpg")

        let categoryLabel = entry.category?.attributes?.label ?? entry.category?.attributes?.term ?? "Drama"
        let categoryID = forcedGenreID ?? entry.category?.attributes?.imId.flatMap(Int.init)
        let projectType = forcedProjectType ?? classifyGenre(id: categoryID, label: categoryLabel)
        var genresList = [categoryLabel]
        if forcedGenreID == 4406 && !genresList.contains(where: { $0.localizedCaseInsensitiveContains("drama") }) {
            genresList.append("Drama")
        }

        let releaseRaw = entry.releaseDate?.label
        let releaseDate = releaseRaw.flatMap { ISO8601DateFormatter().date(from: $0) }
            ?? releaseRaw.flatMap { CineVerseDateFormatters.isoDateParser.date(from: String($0.prefix(10))) }
        let year = releaseRaw.flatMap { Int($0.prefix(4)) } ?? 2025

        let previewLink = entry.links.first {
            $0.attributes?.rel == "enclosure" || ($0.attributes?.type?.contains("video") == true)
        }
        let storeLink = entry.links.first { $0.attributes?.rel == "alternate" }?.attributes?.href

        let previewURLString = previewLink?.attributes?.href
        var extIDs: [MetadataProviderSource: String] = [:]
        if let previewURLString, previewURLString.hasPrefix("https://") {
            extIDs[.openCinema] = previewURLString
        }

        var officialLinks: [ExternalOfficialPlatformLink] = []
        if let storeLink, let url = URL(string: storeLink), url.scheme == "https" {
            officialLinks.append(
                ExternalOfficialPlatformLink(id: "appletv-\(rawID)", siteName: "Apple TV", url: url)
            )
        }

        let status: MediaReleaseStatus = (releaseDate ?? .distantPast) > Date() ? .upcoming : .finished
        // Synthetic chart popularity + rating estimate from chart rank so sorting works smoothly
        let chartScore = max(7.0, 8.8 - Double(min(rankIndex, 45)) * 0.035)
        let ref = MediaReference(provider: .openCinema, kind: .movie, providerID: "itunes-\(rawID)")

        return MediaItem(
            id: ref.id,
            externalIDs: extIDs,
            primarySource: .openCinema,
            projectType: projectType,
            localizedTitle: title,
            originalTitle: title,
            synopsis: entry.summary?.label?.nilIfEmpty ?? "Available in the CineVerse Movie Catalog.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: "US",
            originalLanguage: "en",
            ageRating: projectType == .cartoonMovie ? "6+" : "13+",
            genres: genresList,
            durationMinutes: 115,
            totalSeasons: 1,
            totalEpisodes: 1,
            releaseStatus: status,
            ratings: MultiSourceRatings(tmdbScore: chartScore),
            popularityScore: Double(max(1000 - rankIndex * 10, 100)),
            posterURL: posterURL,
            backdropURL: backdropURL,
            director: entry.artist?.label?.nilIfEmpty ?? "Feature Director",
            trailerURL: previewURLString.flatMap(URL.init(string:)),
            officialPlatformLinks: officialLinks
        )
    }

    private func mapTrack(_ dto: ITunesTrackDTO, rankIndex: Int) -> MediaItem? {
        guard let trackId = dto.trackId,
              let title = (dto.trackName ?? dto.collectionName)?.nilIfEmpty else {
            return nil
        }

        let genre = dto.primaryGenreName ?? "Movie"
        let projectType = classifyGenre(id: nil, label: genre)
        let posterURL = highResArtworkURL(from: dto.artworkUrl100, dimensions: "600x900bb.jpg")
        let backdropURL = highResArtworkURL(from: dto.artworkUrl100, dimensions: "1000x1500bb.jpg")

        let releaseDate = dto.releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) }
            ?? dto.releaseDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: String($0.prefix(10))) }
        let year = dto.releaseDate.flatMap { Int($0.prefix(4)) } ?? 2024
        let durationMins = max((dto.trackTimeMillis ?? 6_900_000) / 60_000, 1)

        var extIDs: [MetadataProviderSource: String] = [:]
        if let preview = dto.previewUrl, preview.hasPrefix("https://") {
            extIDs[.openCinema] = preview
        }

        var officialLinks: [ExternalOfficialPlatformLink] = []
        if let storeStr = dto.trackViewUrl, let url = URL(string: storeStr), url.scheme == "https" {
            officialLinks.append(
                ExternalOfficialPlatformLink(id: "appletv-\(trackId)", siteName: "Apple TV", url: url)
            )
        }

        let ref = MediaReference(provider: .openCinema, kind: .movie, providerID: "itunes-\(trackId)")
        return MediaItem(
            id: ref.id,
            externalIDs: extIDs,
            primarySource: .openCinema,
            projectType: projectType,
            localizedTitle: title,
            originalTitle: title,
            synopsis: dto.longDescription?.nilIfEmpty ?? dto.shortDescription?.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: dto.country ?? "US",
            originalLanguage: "en",
            ageRating: dto.contentAdvisoryRating?.nilIfEmpty ?? "13+",
            genres: [genre],
            durationMinutes: durationMins,
            totalSeasons: 1,
            totalEpisodes: 1,
            releaseStatus: (releaseDate ?? .distantPast) > Date() ? .upcoming : .finished,
            ratings: MultiSourceRatings(tmdbScore: max(7.2, 8.5 - Double(min(rankIndex, 30)) * 0.03)),
            popularityScore: Double(max(850 - rankIndex * 12, 80)),
            posterURL: posterURL,
            backdropURL: backdropURL,
            director: dto.artistName?.nilIfEmpty ?? "Director",
            trailerURL: dto.previewUrl.flatMap(URL.init(string:)),
            officialPlatformLinks: officialLinks
        )
    }

    private func classifyGenre(id: Int?, label: String) -> MediaProjectType {
        let lower = label.lowercased()
        if id == 4410 || lower.contains("kids") || lower.contains("animation") || lower.contains("family") {
            return .cartoonMovie
        }
        if id == 4405 || lower.contains("documentary") {
            return .documentary
        }
        if id == 4431 || lower.contains("anime") {
            return .animeMovie
        }
        return .movie
    }

    private func highResArtworkURL(from raw: String?, dimensions: String) -> URL? {
        guard let raw = raw?.nilIfEmpty else { return nil }
        guard let lastSlash = raw.lastIndex(of: "/") else {
            return URL(string: raw)
        }
        let prefix = String(raw[..<lastSlash])
        return URL(string: "\(prefix)/\(dimensions)")
    }
}
