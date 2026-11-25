import Foundation

public struct TMDBDiscoverParameters: Sendable {
    public var page: Int = 1
    public var language: String = "en-US"
    public var withGenres: [Int] = []
    public var withoutGenres: [Int] = []
    public var yearFrom: Int?
    public var yearTo: Int?
    public var originCountry: String?
    public var originalLanguage: String?
    public var minRating: Double?
    public var maxRating: Double?
    public var maxDurationMinutes: Int?
    public var tvStatusCode: String?
    public var tvTypeCode: String?
    public var sortBy: String = "popularity.desc"

    public init() {}
}

public protocol TMDBServiceProtocol: Sendable {
    func trendingMovies(page: Int, language: String) async throws -> [MediaItem]
    func trendingTV(page: Int, language: String) async throws -> [MediaItem]
    func popularMovies(page: Int, language: String) async throws -> [MediaItem]
    func popularTV(page: Int, language: String) async throws -> [MediaItem]
    func topRatedMovies(page: Int, language: String) async throws -> [MediaItem]
    func topRatedTV(page: Int, language: String) async throws -> [MediaItem]
    func upcomingMovies(page: Int, language: String) async throws -> [MediaItem]
    func nowPlayingMovies(page: Int, language: String) async throws -> [MediaItem]
    func onTheAirTV(page: Int, language: String) async throws -> [MediaItem]
    func discoverMovies(_ params: TMDBDiscoverParameters) async throws -> (items: [MediaItem], hasMore: Bool)
    func discoverTV(_ params: TMDBDiscoverParameters) async throws -> (items: [MediaItem], hasMore: Bool)
    func searchMulti(query: String, page: Int, language: String) async throws -> (items: [MediaItem], hasMore: Bool)
    func movieDetails(id: String, language: String, watchRegion: String) async throws -> (item: MediaItem, imdbID: String?)
    func tvDetails(id: String, language: String, watchRegion: String) async throws -> (item: MediaItem, imdbID: String?)
    func tvSeason(tvID: String, seasonNumber: Int, language: String, defaultDuration: Int) async throws -> MediaSeason
    func movieGenres(language: String) async throws -> [TMDBGenreDTO]
    func tvGenres(language: String) async throws -> [TMDBGenreDTO]
    func validateCredential(_ rawCredential: String) async throws
}

public final class TMDBService: TMDBServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://api.themoviedb.org/3")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func trendingMovies(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "trending/movie/week", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapMovieSummary)
    }

    public func trendingTV(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "trending/tv/week", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBTVSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapTVSummary)
    }

    public func popularMovies(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "movie/popular", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapMovieSummary)
    }

    public func popularTV(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "tv/popular", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBTVSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapTVSummary)
    }

    public func topRatedMovies(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "movie/top_rated", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapMovieSummary)
    }

    public func topRatedTV(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "tv/top_rated", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBTVSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapTVSummary)
    }

    public func upcomingMovies(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "movie/upcoming", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapMovieSummary)
    }

    public func nowPlayingMovies(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "movie/now_playing", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapMovieSummary)
    }

    public func onTheAirTV(page: Int, language: String) async throws -> [MediaItem] {
        let ep = try authorizedEndpoint(path: "tv/on_the_air", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language)
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBTVSummaryDTO>.self)
        return res.results.map(TMDBMapper.mapTVSummary)
    }

    public func discoverMovies(_ params: TMDBDiscoverParameters) async throws -> (items: [MediaItem], hasMore: Bool) {
        var queryItems = baseDiscoverQueryItems(params)
        if let yearFrom = params.yearFrom {
            queryItems.append(URLQueryItem(name: "primary_release_date.gte", value: "\(yearFrom)-01-01"))
        }
        if let yearTo = params.yearTo {
            queryItems.append(URLQueryItem(name: "primary_release_date.lte", value: "\(yearTo)-12-31"))
        }
        let ep = try authorizedEndpoint(path: "discover/movie", queryItems: queryItems)
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMovieSummaryDTO>.self)
        let hasMore = res.page < (res.totalPages ?? res.page)
        return (res.results.map(TMDBMapper.mapMovieSummary), hasMore)
    }

    public func discoverTV(_ params: TMDBDiscoverParameters) async throws -> (items: [MediaItem], hasMore: Bool) {
        var queryItems = baseDiscoverQueryItems(params)
        if let yearFrom = params.yearFrom {
            queryItems.append(URLQueryItem(name: "first_air_date.gte", value: "\(yearFrom)-01-01"))
        }
        if let yearTo = params.yearTo {
            queryItems.append(URLQueryItem(name: "first_air_date.lte", value: "\(yearTo)-12-31"))
        }
        if let tvStatus = params.tvStatusCode {
            queryItems.append(URLQueryItem(name: "with_status", value: tvStatus))
        }
        if let tvType = params.tvTypeCode {
            queryItems.append(URLQueryItem(name: "with_type", value: tvType))
        }
        let ep = try authorizedEndpoint(path: "discover/tv", queryItems: queryItems)
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBTVSummaryDTO>.self)
        let hasMore = res.page < (res.totalPages ?? res.page)
        return (res.results.map(TMDBMapper.mapTVSummary), hasMore)
    }

    public func searchMulti(query: String, page: Int, language: String) async throws -> (items: [MediaItem], hasMore: Bool) {
        let ep = try authorizedEndpoint(path: "search/multi", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "include_adult", value: "false")
        ])
        let res = try await httpClient.send(ep, as: TMDBPagedResponse<TMDBMultiSearchDTO>.self)
        let items = res.results.flatMap(TMDBMapper.mapMultiSearchItems)
        let hasMore = res.page < (res.totalPages ?? res.page)
        return (items, hasMore)
    }

    public func movieDetails(id: String, language: String, watchRegion: String) async throws -> (item: MediaItem, imdbID: String?) {
        let ep = try authorizedEndpoint(path: "movie/\(id)", queryItems: [
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "append_to_response", value: "credits,videos,similar,recommendations,release_dates,watch/providers,external_ids")
        ])
        let dto = try await httpClient.send(ep, as: TMDBMovieDetailsDTO.self)
        return (TMDBMapper.mapMovieDetails(dto, watchRegion: watchRegion), dto.externalIds?.imdbId)
    }

    public func tvDetails(id: String, language: String, watchRegion: String) async throws -> (item: MediaItem, imdbID: String?) {
        let ep = try authorizedEndpoint(path: "tv/\(id)", queryItems: [
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "append_to_response", value: "credits,videos,similar,recommendations,content_ratings,watch/providers,external_ids")
        ])
        let dto = try await httpClient.send(ep, as: TMDBTVDetailsDTO.self)
        return (TMDBMapper.mapTVDetails(dto, watchRegion: watchRegion), dto.externalIds?.imdbId)
    }

    public func tvSeason(tvID: String, seasonNumber: Int, language: String, defaultDuration: Int) async throws -> MediaSeason {
        let ep = try authorizedEndpoint(path: "tv/\(tvID)/season/\(seasonNumber)", queryItems: [
            URLQueryItem(name: "language", value: language)
        ])
        let dto = try await httpClient.send(ep, as: TMDBSeasonDetailsDTO.self)
        return TMDBMapper.mapSeasonDetails(dto, tvID: tvID, defaultDuration: defaultDuration)
    }

    public func movieGenres(language: String) async throws -> [TMDBGenreDTO] {
        let ep = try authorizedEndpoint(path: "genre/movie/list", queryItems: [
            URLQueryItem(name: "language", value: language)
        ])
        return try await httpClient.send(ep, as: TMDBGenreListDTO.self).genres
    }

    public func tvGenres(language: String) async throws -> [TMDBGenreDTO] {
        let ep = try authorizedEndpoint(path: "genre/tv/list", queryItems: [
            URLQueryItem(name: "language", value: language)
        ])
        return try await httpClient.send(ep, as: TMDBGenreListDTO.self).genres
    }

    public func validateCredential(_ rawCredential: String) async throws {
        let cleaned = rawCredential.replacingOccurrences(of: "Bearer ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw NetworkError.missingAPIKey(.tmdb)
        }
        let credential: TMDBCredential = cleaned.count <= 40 ? .apiKey(cleaned) : .bearer(cleaned)
        let ep = buildEndpoint(path: "configuration", queryItems: [], credential: credential)
        _ = try await httpClient.send(ep, as: TMDBConfigurationDTO.self)
    }

    private func baseDiscoverQueryItems(_ params: TMDBDiscoverParameters) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(params.page)),
            URLQueryItem(name: "language", value: params.language),
            URLQueryItem(name: "sort_by", value: params.sortBy),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        if !params.withGenres.isEmpty {
            items.append(URLQueryItem(name: "with_genres", value: params.withGenres.map(String.init).joined(separator: ",")))
        }
        if !params.withoutGenres.isEmpty {
            items.append(URLQueryItem(name: "without_genres", value: params.withoutGenres.map(String.init).joined(separator: ",")))
        }
        if let country = params.originCountry {
            items.append(URLQueryItem(name: "with_origin_country", value: country))
        }
        if let origLang = params.originalLanguage {
            items.append(URLQueryItem(name: "with_original_language", value: origLang))
        }
        if let minRating = params.minRating, minRating > 0 {
            items.append(URLQueryItem(name: "vote_average.gte", value: String(format: "%.1f", minRating)))
        }
        if let maxRating = params.maxRating, maxRating < 10.0 {
            items.append(URLQueryItem(name: "vote_average.lte", value: String(format: "%.1f", maxRating)))
        }
        if params.sortBy.hasPrefix("vote_average") {
            items.append(URLQueryItem(name: "vote_count.gte", value: "5"))
        }
        if let maxRuntime = params.maxDurationMinutes {
            items.append(URLQueryItem(name: "with_runtime.lte", value: String(maxRuntime)))
        }
        return items
    }

    private func authorizedEndpoint(path: String, queryItems: [URLQueryItem]) throws -> Endpoint {
        guard let credential = SecretsProvider.tmdbCredential() else {
            throw NetworkError.missingAPIKey(.tmdb)
        }
        return buildEndpoint(path: path, queryItems: queryItems, credential: credential)
    }

    private func buildEndpoint(path: String, queryItems: [URLQueryItem], credential: TMDBCredential) -> Endpoint {
        var items = queryItems
        var headers = ["Accept": "application/json"]
        switch credential {
        case .apiKey(let key):
            items.append(URLQueryItem(name: "api_key", value: key))
        case .bearer(let token):
            headers["Authorization"] = "Bearer \(token)"
        }
        return Endpoint(baseURL: baseURL, path: path, method: .get, queryItems: items, headers: headers)
    }
}
