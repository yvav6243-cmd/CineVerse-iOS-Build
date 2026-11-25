import Foundation

public struct JikanEpisodeDTO: Decodable, Sendable {
    public let malId: Int
    public let title: String?
    public let titleJapanese: String?
    public let aired: String?

    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case title
        case titleJapanese = "title_japanese"
        case aired
    }
}

public struct JikanEpisodesPaginationDTO: Decodable, Sendable {
    public let hasNextPage: Bool?

    enum CodingKeys: String, CodingKey {
        case hasNextPage = "has_next_page"
    }
}

public struct JikanEpisodesResponseDTO: Decodable, Sendable {
    public let pagination: JikanEpisodesPaginationDTO?
    public let data: [JikanEpisodeDTO]
}

public struct JikanAnimeDTO: Decodable, Sendable {
    public let malId: Int
    public let title: String
    public let titleEnglish: String?
    public let titleJapanese: String?
    public let type: String?
    public let episodes: Int?
    public let status: String?
    public let duration: String?
    public let score: Double?
    public let year: Int?
    public let synopsis: String?
    public let images: JikanImagesDTO?
    public let genres: [JikanNamedDTO]?
    public let studios: [JikanNamedDTO]?
    public let trailer: JikanTrailerDTO?

    enum CodingKeys: String, CodingKey {
        case malId = "mal_id"
        case title
        case titleEnglish = "title_english"
        case titleJapanese = "title_japanese"
        case type, episodes, status, duration, score, year, synopsis, images, genres, studios, trailer
    }
}

public struct JikanImagesDTO: Decodable, Sendable {
    public let jpg: JikanImageURLDTO?
}

public struct JikanImageURLDTO: Decodable, Sendable {
    public let largeImageUrl: String?
    public let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case largeImageUrl = "large_image_url"
        case imageUrl = "image_url"
    }
}

public struct JikanNamedDTO: Decodable, Sendable {
    public let name: String
}

public struct JikanTrailerDTO: Decodable, Sendable {
    public let url: String?
}

public struct JikanAnimeSearchResponseDTO: Decodable, Sendable {
    public let data: [JikanAnimeDTO]
}

public struct JikanAnimeSingleResponseDTO: Decodable, Sendable {
    public let data: JikanAnimeDTO
}

public protocol JikanServiceProtocol: Sendable {
    func episodes(malID: Int, animeID: String, defaultDuration: Int) async throws -> [MediaEpisode]
    func searchAnime(query: String, limit: Int) async throws -> [MediaItem]
    func animeDetails(malID: Int) async throws -> MediaItem?
}

public extension JikanServiceProtocol {
    func searchAnime(query: String, limit: Int) async throws -> [MediaItem] { [] }
    func animeDetails(malID: Int) async throws -> MediaItem? { nil }
}

public final class JikanService: JikanServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://api.jikan.moe/v4")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func episodes(malID: Int, animeID: String, defaultDuration: Int) async throws -> [MediaEpisode] {
        var collected: [MediaEpisode] = []
        var page = 1
        var hasMore = true

        while hasMore && page <= 3 {
            let ep = Endpoint(
                baseURL: baseURL,
                path: "anime/\(malID)/episodes",
                queryItems: [URLQueryItem(name: "page", value: String(page))]
            )
            let response = try await httpClient.send(ep, as: JikanEpisodesResponseDTO.self)
            let mapped = response.data.map { dto in
                let airedDate: Date? = dto.aired.flatMap { raw in
                    ISO8601DateFormatter().date(from: raw)
                        ?? CineVerseDateFormatters.isoDateParser.date(from: String(raw.prefix(10)))
                }
                return MediaEpisode(
                    id: "anilist:anime:\(animeID):s1:e\(dto.malId)",
                    seasonNumber: 1,
                    episodeNumber: dto.malId,
                    title: dto.title?.nilIfEmpty ?? "Episode \(dto.malId)",
                    originalTitle: dto.titleJapanese?.nilIfEmpty,
                    synopsis: "Episode \(dto.malId)",
                    durationMinutes: defaultDuration,
                    airDate: airedDate
                )
            }
            collected.append(contentsOf: mapped)
            hasMore = response.pagination?.hasNextPage ?? false
            page += 1
        }

        return collected
    }

    public func searchAnime(query: String, limit: Int = 15) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let ep = Endpoint(
            baseURL: baseURL,
            path: "anime",
            queryItems: [
                URLQueryItem(name: "q", value: trimmed),
                URLQueryItem(name: "sfw", value: "true"),
                URLQueryItem(name: "limit", value: String(min(max(limit, 1), 25)))
            ],
            timeoutInterval: 5.5
        )
        let response = try await httpClient.send(ep, as: JikanAnimeSearchResponseDTO.self)
        return response.data.map(Self.mapAnime)
    }

    public func animeDetails(malID: Int) async throws -> MediaItem? {
        let ep = Endpoint(baseURL: baseURL, path: "anime/\(malID)", timeoutInterval: 6.0)
        let response = try await httpClient.send(ep, as: JikanAnimeSingleResponseDTO.self)
        return Self.mapAnime(response.data)
    }

    private static func mapAnime(_ dto: JikanAnimeDTO) -> MediaItem {
        let upperType = (dto.type ?? "TV").uppercased()
        let projectType: MediaProjectType = {
            if upperType == "MOVIE" { return .animeMovie }
            if upperType == "OVA" || upperType == "SPECIAL" || upperType == "ONA" { return .special }
            return .anime
        }()
        let releaseStatus: MediaReleaseStatus = {
            let lower = (dto.status ?? "").lowercased()
            if lower.contains("currently airing") { return .releasing }
            if lower.contains("not yet aired") { return .upcoming }
            return .finished
        }()
        let posterStr = dto.images?.jpg?.largeImageUrl ?? dto.images?.jpg?.imageUrl
        let posterURL = posterStr.flatMap(URL.init(string:))
        let trailerURL = dto.trailer?.url.flatMap(URL.init(string:))
        let durationMin = parseDurationMinutes(dto.duration)
        let locTitle = dto.titleEnglish?.nilIfEmpty ?? dto.title
        let studioName = dto.studios?.first?.name ?? ""

        return MediaItem(
            id: "opencinema:movie:mal-\(dto.malId)",
            externalIDs: [.openCinema: "mal-\(dto.malId)"],
            primarySource: .openCinema,
            projectType: projectType,
            localizedTitle: locTitle,
            originalTitle: dto.titleJapanese?.nilIfEmpty ?? dto.title,
            synopsis: dto.synopsis?.nilIfEmpty ?? "No description available.",
            releaseYear: dto.year ?? 0,
            countryOfOrigin: "JP",
            originalLanguage: "ja",
            ageRating: "13+",
            genres: dto.genres?.map(\.name) ?? ["Anime"],
            durationMinutes: durationMin > 0 ? durationMin : 24,
            totalSeasons: 1,
            totalEpisodes: max(dto.episodes ?? 1, 1),
            releaseStatus: releaseStatus,
            ratings: MultiSourceRatings(aniListScore: dto.score),
            popularityScore: dto.score.map { $0 * 40 } ?? 180,
            posterURL: posterURL,
            backdropURL: posterURL,
            director: studioName.nilIfEmpty ?? "Animation Studio",
            studio: studioName,
            alternativeTitles: [dto.title],
            trailerURL: trailerURL
        )
    }

    private static func parseDurationMinutes(_ raw: String?) -> Int {
        guard let raw else { return 0 }
        let digits = raw.split(separator: " ").first.flatMap { Int($0) } ?? 0
        if raw.lowercased().contains("hr") {
            return digits * 60
        }
        return digits
    }
}
