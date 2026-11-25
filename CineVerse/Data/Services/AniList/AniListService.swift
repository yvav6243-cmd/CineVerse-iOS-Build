import Foundation

public struct AniListSearchParameters: Sendable {
    public var page: Int = 1
    public var perPage: Int = 30
    public var search: String?
    public var sort: [String] = ["POPULARITY_DESC"]
    public var genres: [String]?
    public var yearFrom: Int?
    public var yearTo: Int?
    public var countryOfOrigin: String?
    public var formats: [String]?
    public var status: String?
    public var minRating: Double?
    public var maxRating: Double?
    public var maxDurationMinutes: Int?

    public init() {}
}

public protocol AniListServiceProtocol: Sendable {
    func fetchMediaPage(_ params: AniListSearchParameters) async throws -> (items: [MediaItem], hasMore: Bool)
    func mediaDetails(id: Int) async throws -> (item: MediaItem, malID: Int?, streamingLinks: [AniListStreamingEpisodeDTO])
    func airingSchedule(from: Date, to: Date, page: Int) async throws -> [PremiereEvent]
    func genres() async throws -> [String]
    func searchEntities(query: String) async throws -> [MediaItem]
}

public extension AniListServiceProtocol {
    func searchEntities(query: String) async throws -> [MediaItem] { [] }
}

public final class AniListService: AniListServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let endpointURL = URL.constant("https://graphql.anilist.co")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchMediaPage(_ params: AniListSearchParameters) async throws -> (items: [MediaItem], hasMore: Bool) {
        var variables: [String: Any] = [
            "page": params.page,
            "perPage": params.perPage,
            "sort": params.sort
        ]
        if let search = params.search?.nilIfEmpty {
            variables["search"] = search
        }
        if let genres = params.genres, !genres.isEmpty {
            variables["genres"] = genres
        }
        if let yearFrom = params.yearFrom {
            variables["startDateGreater"] = yearFrom * 10000 + 101
        }
        if let yearTo = params.yearTo {
            variables["startDateLesser"] = yearTo * 10000 + 1231
        }
        if let country = params.countryOfOrigin {
            variables["countryOfOrigin"] = country
        }
        if let formats = params.formats, !formats.isEmpty {
            variables["formats"] = formats
        }
        if let status = params.status {
            variables["status"] = status
        }
        if let minRating = params.minRating, minRating > 0 {
            variables["averageScoreGreater"] = Int((minRating * 10.0).rounded())
        }
        if let maxRating = params.maxRating, maxRating < 10.0 {
            variables["averageScoreLesser"] = Int((maxRating * 10.0).rounded()) + 1
        }
        if let maxDuration = params.maxDurationMinutes {
            variables["durationLesser"] = maxDuration + 1
        }

        let ep = try makeGraphQLEndpoint(query: AniListQueries.pageMedia, variables: variables)
        let response = try await httpClient.send(ep, as: AniListGraphQLResponse<AniListPageDataDTO>.self)
        let pageDTO = response.data?.page
        let items = (pageDTO?.media ?? []).map(AniListMapper.mapMedia)
        let hasMore = pageDTO?.pageInfo?.hasNextPage ?? false
        return (items, hasMore)
    }

    public func mediaDetails(id: Int) async throws -> (item: MediaItem, malID: Int?, streamingLinks: [AniListStreamingEpisodeDTO]) {
        let ep = try makeGraphQLEndpoint(
            query: AniListQueries.mediaDetails,
            variables: ["id": id]
        )
        let response = try await httpClient.send(ep, as: AniListGraphQLResponse<AniListMediaDataDTO>.self)
        guard let media = response.data?.media else {
            throw NetworkError.http(statusCode: 404, message: "Anime entry not found on AniList.")
        }
        return (
            AniListMapper.mapMedia(media),
            media.idMal,
            media.streamingEpisodes ?? []
        )
    }

    public func airingSchedule(from: Date, to: Date, page: Int) async throws -> [PremiereEvent] {
        let ep = try makeGraphQLEndpoint(
            query: AniListQueries.airingSchedule,
            variables: [
                "page": page,
                "airingAtGreater": Int(from.timeIntervalSince1970),
                "airingAtLesser": Int(to.timeIntervalSince1970)
            ]
        )
        let response = try await httpClient.send(ep, as: AniListGraphQLResponse<AniListPageDataDTO>.self)
        return (response.data?.page.airingSchedules ?? []).compactMap(AniListMapper.mapAiringEvent)
    }

    public func genres() async throws -> [String] {
        let ep = try makeGraphQLEndpoint(query: AniListQueries.genres, variables: [:])
        let response = try await httpClient.send(ep, as: AniListGraphQLResponse<AniListGenresDataDTO>.self)
        return (response.data?.genreCollection ?? []).filter { $0.lowercased() != "hentai" }
    }

    public func searchEntities(query: String) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let ep = try makeGraphQLEndpoint(query: AniListQueries.searchEntities, variables: ["q": trimmed])
        let response = try await httpClient.send(ep, as: AniListGraphQLResponse<AniListEntitySearchDataDTO>.self)
        guard let data = response.data else { return [] }

        var results: [MediaItem] = []
        for studio in data.studios?.studios ?? [] {
            let sName = studio.name ?? ""
            for node in (studio.media?.nodes ?? []) where node.isAdult != true {
                var item = AniListMapper.mapMedia(node)
                if !sName.isEmpty { item.studio = sName }
                results.append(item)
            }
        }
        for charEntry in data.characters?.characters ?? [] {
            let cName = charEntry.name?.full ?? ""
            for node in (charEntry.media?.nodes ?? []) where node.isAdult != true {
                var item = AniListMapper.mapMedia(node)
                if !cName.isEmpty {
                    item.cast.append(MediaCreditPerson(id: "ani:c:\(node.id):\(cName)", name: cName, roleOrCharacter: cName, department: "Voice"))
                }
                results.append(item)
            }
        }
        for staffEntry in data.staff?.staff ?? [] {
            let pName = staffEntry.name?.full ?? ""
            for node in (staffEntry.staffMedia?.nodes ?? []) where node.isAdult != true {
                var item = AniListMapper.mapMedia(node)
                if !pName.isEmpty {
                    item.cast.append(MediaCreditPerson(id: "ani:s:\(node.id):\(pName)", name: pName, roleOrCharacter: "Staff / Creator", department: "Staff"))
                }
                results.append(item)
            }
        }
        return results
    }

    private func makeGraphQLEndpoint(query: String, variables: [String: Any]) throws -> Endpoint {
        let payload: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return Endpoint(
            baseURL: endpointURL,
            path: "",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/json"
            ],
            body: body
        )
    }
}
