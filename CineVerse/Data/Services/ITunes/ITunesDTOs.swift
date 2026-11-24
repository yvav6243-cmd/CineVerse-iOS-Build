import Foundation

// MARK: - Apple iTunes RSS Feed DTOs

public struct ITunesRSSRootDTO: Decodable, Sendable {
    public let feed: ITunesRSSFeedDTO?
}

public struct ITunesRSSFeedDTO: Decodable, Sendable {
    public let entry: [ITunesRSSEntryDTO]?

    enum CodingKeys: String, CodingKey {
        case entry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let array = try? container.decode([ITunesRSSEntryDTO].self, forKey: .entry) {
            self.entry = array
        } else if let single = try? container.decode(ITunesRSSEntryDTO.self, forKey: .entry) {
            self.entry = [single]
        } else {
            self.entry = []
        }
    }
}

public struct ITunesRSSLabelDTO: Decodable, Sendable {
    public let label: String?
}

public struct ITunesRSSImageDTO: Decodable, Sendable {
    public let label: String?
}

public struct ITunesRSSIDAttributesDTO: Decodable, Sendable {
    public let imId: String?

    enum CodingKeys: String, CodingKey {
        case imId = "im:id"
    }
}

public struct ITunesRSSIDDTO: Decodable, Sendable {
    public let label: String?
    public let attributes: ITunesRSSIDAttributesDTO?
}

public struct ITunesRSSCategoryAttributesDTO: Decodable, Sendable {
    public let imId: String?
    public let label: String?
    public let term: String?

    enum CodingKeys: String, CodingKey {
        case imId = "im:id"
        case label
        case term
    }
}

public struct ITunesRSSCategoryDTO: Decodable, Sendable {
    public let attributes: ITunesRSSCategoryAttributesDTO?
}

public struct ITunesRSSLinkAttributesDTO: Decodable, Sendable {
    public let rel: String?
    public let type: String?
    public let href: String?
    public let title: String?
}

public struct ITunesRSSLinkItemDTO: Decodable, Sendable {
    public let attributes: ITunesRSSLinkAttributesDTO?
    public let duration: ITunesRSSLabelDTO?

    enum CodingKeys: String, CodingKey {
        case attributes
        case duration = "im:duration"
    }
}

public struct ITunesRSSEntryDTO: Decodable, Sendable {
    public let name: ITunesRSSLabelDTO?
    public let images: [ITunesRSSImageDTO]?
    public let summary: ITunesRSSLabelDTO?
    public let title: ITunesRSSLabelDTO?
    public let id: ITunesRSSIDDTO?
    public let artist: ITunesRSSLabelDTO?
    public let category: ITunesRSSCategoryDTO?
    public let releaseDate: ITunesRSSLabelDTO?
    public let links: [ITunesRSSLinkItemDTO]

    enum CodingKeys: String, CodingKey {
        case name = "im:name"
        case images = "im:image"
        case summary
        case title
        case id
        case artist = "im:artist"
        case category
        case releaseDate = "im:releaseDate"
        case link
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try? c.decode(ITunesRSSLabelDTO.self, forKey: .name)
        self.images = try? c.decode([ITunesRSSImageDTO].self, forKey: .images)
        self.summary = try? c.decode(ITunesRSSLabelDTO.self, forKey: .summary)
        self.title = try? c.decode(ITunesRSSLabelDTO.self, forKey: .title)
        self.id = try? c.decode(ITunesRSSIDDTO.self, forKey: .id)
        self.artist = try? c.decode(ITunesRSSLabelDTO.self, forKey: .artist)
        self.category = try? c.decode(ITunesRSSCategoryDTO.self, forKey: .category)
        self.releaseDate = try? c.decode(ITunesRSSLabelDTO.self, forKey: .releaseDate)
        if let arr = try? c.decode([ITunesRSSLinkItemDTO].self, forKey: .link) {
            self.links = arr
        } else if let single = try? c.decode(ITunesRSSLinkItemDTO.self, forKey: .link) {
            self.links = [single]
        } else {
            self.links = []
        }
    }
}

// MARK: - Apple iTunes Search & Lookup DTOs

public struct ITunesSearchResponseDTO: Decodable, Sendable {
    public let resultCount: Int?
    public let results: [ITunesTrackDTO]?
}

public struct ITunesTrackDTO: Decodable, Sendable {
    public let wrapperType: String?
    public let kind: String?
    public let trackId: Int?
    public let collectionId: Int?
    public let trackName: String?
    public let collectionName: String?
    public let artistName: String?
    public let trackViewUrl: String?
    public let previewUrl: String?
    public let artworkUrl100: String?
    public let releaseDate: String?
    public let trackTimeMillis: Int?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let country: String?
    public let primaryGenreName: String?
    public let contentAdvisoryRating: String?
    public let shortDescription: String?
    public let longDescription: String?
}

// MARK: - Apple iTunes Mapper

enum ITunesMapper {
    static func mapRSSEntry(
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

    static func mapTrack(_ dto: ITunesTrackDTO, rankIndex: Int) -> MediaItem? {
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

    private static func classifyGenre(id: Int?, label: String) -> MediaProjectType {
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

    private static func highResArtworkURL(from raw: String?, dimensions: String) -> URL? {
        guard let raw = raw?.nilIfEmpty else { return nil }
        guard let lastSlash = raw.lastIndex(of: "/") else {
            return URL(string: raw)
        }
        let prefix = String(raw[..<lastSlash])
        return URL(string: "\(prefix)/\(dimensions)")
    }
}
