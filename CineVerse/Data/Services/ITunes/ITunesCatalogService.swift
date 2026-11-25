import Foundation

public struct ITunesPreviewMatch: Sendable, Hashable {
    public let url: URL
    public let label: String

    public init(url: URL, label: String) {
        self.url = url
        self.label = label
    }
}

public protocol ITunesCatalogServiceProtocol: Sendable {
    func topMovies(genreID: Int?, limit: Int) async throws -> [MediaItem]
    func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem]
    func searchMovies(query: String, limit: Int) async throws -> [MediaItem]
    func lookupDetails(providerID: String) async throws -> MediaItem?
    func findPlayablePreviews(
        title: String,
        originalTitle: String,
        isEpisodic: Bool,
        seasonNumber: Int?,
        episodeNumber: Int?,
        limit: Int
    ) async -> [ITunesPreviewMatch]
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
            ITunesMapper.mapRSSEntry(
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
            .compactMap { idx, dto in ITunesMapper.mapTrack(dto, rankIndex: idx) }

        let openMatches = openCinemaShowcase().filter {
            $0.localizedTitle.localizedCaseInsensitiveContains(trimmed)
                || $0.originalTitle.localizedCaseInsensitiveContains(trimmed)
        }
        return openMatches + movieMatches
    }

    public func lookupDetails(providerID: String) async throws -> MediaItem? {
        if providerID.hasPrefix("open-") {
            return openCinemaShowcase().first {
                $0.id == "opencinema:movie:\(providerID)" || $0.id == "opencinema:tv:\(providerID)"
            }
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
        guard var mapped = ITunesMapper.mapTrack(track, rankIndex: 0) else {
            return nil
        }
        let currentID = mapped.id
        if let genreName = track.primaryGenreName,
           let matchedGenreID = Self.genreIDsByName.first(where: { $0.name.lowercased() == genreName.lowercased() })?.id,
           let related = try? await topMovies(genreID: matchedGenreID, limit: 12) {
            mapped.similarProjectIDs = related.filter { $0.id != currentID }.prefix(10).map(\.id)
        }
        return mapped
    }

    public func findPlayablePreviews(
        title: String,
        originalTitle: String,
        isEpisodic: Bool,
        seasonNumber: Int?,
        episodeNumber: Int?,
        limit: Int
    ) async -> [ITunesPreviewMatch] {
        guard limit > 0 else { return [] }
        var seenTerms: Set<String> = []
        var candidates: [String] = []
        for raw in [title, originalTitle] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seenTerms.insert(trimmed.lowercased()).inserted else { continue }
            candidates.append(trimmed)
        }

        let targetKind = isEpisodic ? "tv-episode" : "feature-movie"
        var rankedMatches: [(score: Int, match: ITunesPreviewMatch)] = []
        var seenURLs: Set<String> = []

        for term in candidates {
            let ep = Endpoint(
                baseURL: baseURL,
                path: "search",
                queryItems: [
                    URLQueryItem(name: "term", value: term),
                    URLQueryItem(name: "country", value: "US"),
                    URLQueryItem(name: "limit", value: "25")
                ],
                timeoutInterval: 8
            )
            guard let res = try? await httpClient.send(ep, as: ITunesSearchResponseDTO.self),
                  let results = res.results else {
                continue
            }

            let normalizedTarget = term.normalizedForComparison
            guard !normalizedTarget.isEmpty else { continue }

            for dto in results {
                let kind = dto.kind ?? ""
                guard kind == "feature-movie" || kind == "tv-episode",
                      let previewStr = dto.previewUrl,
                      previewStr.hasPrefix("https://"),
                      let previewURL = URL(string: previewStr),
                      previewURL.scheme?.lowercased() == "https" else {
                    continue
                }

                let rawTrackName = dto.trackName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let rawCollectionName = dto.collectionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let tNorm = rawTrackName.normalizedForComparison
                let cNorm = rawCollectionName.normalizedForComparison

                let matchesTrack = !tNorm.isEmpty && (tNorm.contains(normalizedTarget) || normalizedTarget.contains(tNorm))
                let matchesCollection = !cNorm.isEmpty && (cNorm.contains(normalizedTarget) || normalizedTarget.contains(cNorm))
                guard matchesTrack || matchesCollection else { continue }

                var rankScore = 0
                if kind == targetKind {
                    rankScore += 100
                }
                if isEpisodic {
                    if let epNum = episodeNumber, let trackNum = dto.trackNumber, trackNum == epNum {
                        rankScore += 50
                    }
                    if let sNum = seasonNumber,
                       rawCollectionName.localizedCaseInsensitiveContains("Season \(sNum)") {
                        rankScore += 25
                    }
                }
                if matchesTrack {
                    rankScore += 10
                }

                let trackLabel = rawTrackName.isEmpty ? term : rawTrackName
                let rawLabel: String
                if kind == "feature-movie" {
                    rawLabel = "Official Trailer · \(trackLabel)"
                } else {
                    rawLabel = "Episode Preview · \(rawCollectionName) · \(trackLabel)"
                }
                let finalLabel = String(rawLabel.prefix(70))

                if seenURLs.insert(previewURL.absoluteString).inserted {
                    rankedMatches.append((rankScore, ITunesPreviewMatch(url: previewURL, label: finalLabel)))
                }
            }
        }

        let sorted = rankedMatches.sorted { $0.score > $1.score }
        return Array(sorted.prefix(limit).map(\.match))
    }

    public func findPlayablePreviewURL(
        title: String,
        originalTitle: String,
        isEpisodic: Bool,
        episodeNumber: Int?
    ) async -> URL? {
        await findPlayablePreviews(
            title: title,
            originalTitle: originalTitle,
            isEpisodic: isEpisodic,
            seasonNumber: nil,
            episodeNumber: episodeNumber,
            limit: 1
        ).first?.url
    }

    public func openCinemaShowcase() -> [MediaItem] {
        OpenCinemaLibrary.items
    }

    public func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)? {
        if let first = OpenCinemaLibrary.streams(forItemID: providerID).first {
            let fmt: VideoStreamFormat = (first.url.pathExtension.lowercased() == "m3u8" || first.url.absoluteString.contains(".m3u8")) ? .hls : .mp4
            return (first.url, fmt, "CineVerse Open Cinema · \(first.label)")
        }
        let fullID = providerID.hasPrefix("opencinema:") ? providerID : "opencinema:movie:\(providerID)"
        guard let match = OpenCinemaLibrary.items.first(where: { $0.id == fullID }),
              let raw = match.externalIDs[.openCinema],
              let url = URL(string: raw) else {
            return nil
        }
        let fmt: VideoStreamFormat = url.pathExtension.lowercased() == "m3u8" || raw.contains(".m3u8") ? .hls : .mp4
        return (url, fmt, "CineVerse Open Cinema (Full HD Stream)")
    }
}
