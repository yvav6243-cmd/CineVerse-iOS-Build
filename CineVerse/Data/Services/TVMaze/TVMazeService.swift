import Foundation

public protocol TVMazeServiceProtocol: Sendable {
    func searchShows(query: String) async throws -> [MediaItem]
    func showIndex(page: Int) async throws -> [MediaItem]
    func showDetails(id: String) async throws -> MediaItem
    func lookupByIMDB(_ imdbID: String) async throws -> (id: Int, rating: Double?)?
    func schedule(countryCode: String, date: Date) async throws -> [PremiereEvent]
    func webSchedule(date: Date) async throws -> [PremiereEvent]
}

public final class TVMazeService: TVMazeServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://api.tvmaze.com")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func searchShows(query: String) async throws -> [MediaItem] {
        let ep = Endpoint(
            baseURL: baseURL,
            path: "search/shows",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        let results = try await httpClient.send(ep, as: [TVMazeSearchResultWithRatingDTO].self)
        return results.map {
            TVMazeMapper.mapShowWithRating($0.show.asShowDTO, averageRating: $0.show.rating?.average)
        }
    }

    public func showIndex(page: Int) async throws -> [MediaItem] {
        let ep = Endpoint(
            baseURL: baseURL,
            path: "shows",
            queryItems: [URLQueryItem(name: "page", value: String(max(page - 1, 0)))]
        )
        let results = try await httpClient.send(ep, as: [TVMazeRatedShowDTO].self)
        return results
            .sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
            .map { TVMazeMapper.mapShowWithRating($0.asShowDTO, averageRating: $0.rating?.average) }
    }

    public func showDetails(id: String) async throws -> MediaItem {
        let ep = Endpoint(
            baseURL: baseURL,
            path: "shows/\(id)",
            queryItems: [
                URLQueryItem(name: "embed[]", value: "cast"),
                URLQueryItem(name: "embed[]", value: "seasons"),
                URLQueryItem(name: "embed[]", value: "episodes")
            ]
        )
        let dto = try await httpClient.send(ep, as: TVMazeRatedShowDTO.self)
        return TVMazeMapper.mapShowWithRating(dto.asShowDTO, averageRating: dto.rating?.average)
    }

    public func lookupByIMDB(_ imdbID: String) async throws -> (id: Int, rating: Double?)? {
        let ep = Endpoint(
            baseURL: baseURL,
            path: "lookup/shows",
            queryItems: [URLQueryItem(name: "imdb", value: imdbID)]
        )
        do {
            let dto = try await httpClient.send(ep, as: TVMazeRatedShowDTO.self)
            return (dto.id, dto.rating?.average)
        } catch NetworkError.http(let statusCode, _) where statusCode == 404 {
            return nil
        }
    }

    public func schedule(countryCode: String, date: Date) async throws -> [PremiereEvent] {
        let dateStr = CineVerseDateFormatters.isoDateParser.string(from: date)
        let ep = Endpoint(
            baseURL: baseURL,
            path: "schedule",
            queryItems: [
                URLQueryItem(name: "country", value: countryCode),
                URLQueryItem(name: "date", value: dateStr)
            ]
        )
        let entries = try await httpClient.send(ep, as: [TVMazeScheduleEntryDTO].self)
        return entries.compactMap(TVMazeMapper.mapScheduleEntry)
    }

    public func webSchedule(date: Date) async throws -> [PremiereEvent] {
        let dateStr = CineVerseDateFormatters.isoDateParser.string(from: date)
        let ep = Endpoint(
            baseURL: baseURL,
            path: "schedule/web",
            queryItems: [URLQueryItem(name: "date", value: dateStr)]
        )
        let entries = try await httpClient.send(ep, as: [TVMazeScheduleEntryDTO].self)
        return entries.compactMap(TVMazeMapper.mapScheduleEntry)
    }
}

private struct TVMazeSearchResultWithRatingDTO: Decodable, Sendable {
    let score: Double
    let show: TVMazeRatedShowDTO
}

private struct TVMazeRatedShowDTO: Decodable, Sendable {
    let id: Int
    let url: String?
    let name: String
    let type: String?
    let language: String?
    let genres: [String]?
    let status: String?
    let runtime: Int?
    let averageRuntime: Int?
    let premiered: String?
    let ended: String?
    let officialSite: String?
    let weight: Int?
    let rating: TVMazeRatingDTO?
    let network: TVMazeNetworkDTO?
    let webChannel: TVMazeNetworkDTO?
    let externals: TVMazeExternalsDTO?
    let image: TVMazeImageDTO?
    let summary: String?
    let links: TVMazeLinksDTO?
    let embedded: TVMazeEmbeddedDTO?

    enum CodingKeys: String, CodingKey {
        case id, url, name, type, language, genres, status, runtime, averageRuntime
        case premiered, ended, officialSite, weight, rating, network, webChannel, externals, image, summary
        case links = "_links"
        case embedded = "_embedded"
    }

    var asShowDTO: TVMazeShowDTO {
        TVMazeShowDTO(
            id: id,
            url: url,
            name: name,
            type: type,
            language: language,
            genres: genres,
            status: status,
            runtime: runtime,
            averageRuntime: averageRuntime,
            premiered: premiered,
            ended: ended,
            officialSite: officialSite,
            weight: weight,
            network: network,
            webChannel: webChannel,
            externals: externals,
            image: image,
            summary: summary,
            links: links,
            embedded: embedded
        )
    }
}
