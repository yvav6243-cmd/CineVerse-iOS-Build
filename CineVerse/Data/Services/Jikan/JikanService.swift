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

public protocol JikanServiceProtocol: Sendable {
    func episodes(malID: Int, animeID: String, defaultDuration: Int) async throws -> [MediaEpisode]
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

        // Cap at 3 pages (300 episodes) to respect Jikan rate limits on initial open
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
}
