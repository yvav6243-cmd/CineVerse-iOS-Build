import Foundation

public struct CatalogPage: Sendable {
    public let items: [MediaItem]
    public let hasMore: Bool

    public init(items: [MediaItem], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }
}

public protocol CatalogRepositoryProtocol: Sendable {
    func homeFeed(_ section: HomeSectionType, language: String) async throws -> [MediaItem]
    func discover(criteria: CatalogFilterCriteria, page: Int, language: String) async throws -> CatalogPage
    func search(query: String, criteria: CatalogFilterCriteria, page: Int, language: String) async throws -> CatalogPage
    func suggestions(prefix: String, language: String) async -> [String]
    func genres(for category: MediaProjectType?, language: String) async -> [String]
    func randomPick(criteria: CatalogFilterCriteria, language: String) async throws -> MediaItem?
}

public final class CatalogRepository: CatalogRepositoryProtocol, @unchecked Sendable {
    private let tmdb: TMDBServiceProtocol
    private let aniList: AniListServiceProtocol
    private let tvMaze: TVMazeServiceProtocol
    private let cache: ResponseDiskCache

    private let cacheTTL: TimeInterval = 6 * 3600

    public init(
        tmdb: TMDBServiceProtocol,
        aniList: AniListServiceProtocol,
        tvMaze: TVMazeServiceProtocol,
        cache: ResponseDiskCache
    ) {
        self.tmdb = tmdb
        self.aniList = aniList
        self.tvMaze = tvMaze
        self.cache = cache
    }

    public func homeFeed(_ section: HomeSectionType, language: String) async throws -> [MediaItem] {
        let cacheKey = "home:\(section.rawValue):\(language)"
        if let cached = await cache.load(key: cacheKey, maxAge: cacheTTL, as: [MediaItem].self) {
            return cached
        }

        let hasTMDB = SecretsProvider.tmdbCredential() != nil
        do {
            let items: [MediaItem]
            switch section {
            case .recentlyAdded:
                items = try await fetchRecentlyAdded(language: language, hasTMDB: hasTMDB)
            case .trendingMovies:
                guard hasTMDB else { throw NetworkError.missingAPIKey(.tmdb) }
                items = try await tmdb.trendingMovies(page: 1, language: language)
            case .popularAnime:
                var params = AniListSearchParameters()
                params.sort = ["TRENDING_DESC"]
                params.perPage = 25
                items = try await aniList.fetchMediaPage(params).items
            case .popularTVShows:
                if hasTMDB {
                    items = try await tmdb.popularTV(page: 1, language: language)
                } else {
                    items = Array(try await tvMaze.showIndex(page: 1).prefix(25))
                }
            case .upcomingReleases:
                items = try await fetchUpcoming(language: language, hasTMDB: hasTMDB)
            case .topRated:
                items = try await fetchTopRated(language: language, hasTMDB: hasTMDB)
            case .continueWatching, .recommendedForYou, .recentlyWatched, .yourFavorites:
                items = []
            }

            if !items.isEmpty {
                await cache.store(items, forKey: cacheKey)
            }
            return items
        } catch {
            if let stale = await cache.loadEvenIfStale(key: cacheKey, as: [MediaItem].self) {
                return stale
            }
            throw error
        }
    }

    public func discover(criteria: CatalogFilterCriteria, page: Int, language: String) async throws -> CatalogPage {
        let hasTMDB = SecretsProvider.tmdbCredential() != nil
        let requests = CatalogQueryPlanner.planRequests(
            criteria: criteria,
            page: page,
            language: language,
            hasTMDBCredential: hasTMDB
        )

        if requests.isEmpty && !hasTMDB {
            throw NetworkError.missingAPIKey(.tmdb)
        }

        var collected: [MediaItem] = []
        var anyHasMore = false
        var excludeJapanese = false

        try await withThrowingTaskGroup(of: (items: [MediaItem], hasMore: Bool, excludeJa: Bool).self) { group in
            for request in requests {
                group.addTask { [tmdb, aniList, tvMaze] in
                    switch request {
                    case .tmdbMovies(let params, let exJa):
                        let res = try await tmdb.discoverMovies(params)
                        return (res.items, res.hasMore, exJa)
                    case .tmdbTV(let params, let exJa):
                        let res = try await tmdb.discoverTV(params)
                        return (res.items, res.hasMore, exJa)
                    case .aniList(let params):
                        let res = try await aniList.fetchMediaPage(params)
                        return (res.items, res.hasMore, false)
                    case .tvMazeIndex(let pg):
                        let res = try await tvMaze.showIndex(page: pg)
                        return (Array(res.prefix(30)), !res.isEmpty, false)
                    }
                }
            }

            for try await part in group {
                collected.append(contentsOf: part.items)
                if part.hasMore { anyHasMore = true }
                if part.excludeJa { excludeJapanese = true }
            }
        }

        let merged = MediaMerger.merge(collected)
        let processed = CatalogQueryPlanner.postFilterAndSort(
            items: merged,
            criteria: criteria,
            excludeJapaneseForCartoons: excludeJapanese
        )
        return CatalogPage(items: processed, hasMore: anyHasMore)
    }

    public func search(query: String, criteria: CatalogFilterCriteria, page: Int, language: String) async throws -> CatalogPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await discover(criteria: criteria, page: page, language: language)
        }

        let hasTMDB = SecretsProvider.tmdbCredential() != nil
        var allItems: [MediaItem] = []
        var anyHasMore = false

        await withTaskGroup(of: (items: [MediaItem], hasMore: Bool).self) { group in
            if hasTMDB {
                group.addTask { [tmdb] in
                    (try? await tmdb.searchMulti(query: trimmed, page: page, language: language)) ?? ([], false)
                }
            }
            group.addTask { [aniList] in
                var params = AniListSearchParameters()
                params.page = page
                params.perPage = 20
                params.search = trimmed
                params.sort = ["SEARCH_MATCH"]
                return (try? await aniList.fetchMediaPage(params)) ?? ([], false)
            }
            if page == 1 {
                group.addTask { [tvMaze] in
                    let shows = (try? await tvMaze.searchShows(query: trimmed)) ?? []
                    return (shows, false)
                }
            }

            for await result in group {
                allItems.append(contentsOf: result.items)
                if result.hasMore { anyHasMore = true }
            }
        }

        let merged = MediaMerger.merge(allItems)
        let filtered = CatalogQueryPlanner.postFilterAndSort(
            items: merged,
            criteria: criteria,
            query: trimmed
        )
        return CatalogPage(items: filtered, hasMore: anyHasMore)
    }

    public func suggestions(prefix: String, language: String) async -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        async let aniTask: [MediaItem] = {
            var params = AniListSearchParameters()
            params.page = 1
            params.perPage = 5
            params.search = trimmed
            params.sort = ["SEARCH_MATCH"]
            return (try? await aniList.fetchMediaPage(params).items) ?? []
        }()

        async let tmdbTask: [MediaItem] = {
            guard SecretsProvider.tmdbCredential() != nil else { return [] }
            return (try? await tmdb.searchMulti(query: trimmed, page: 1, language: language).items) ?? []
        }()

        let combined = await tmdbTask + aniTask
        var seen: Set<String> = []
        var titles: [String] = []
        for item in combined {
            let key = item.localizedTitle.lowercased()
            if seen.insert(key).inserted {
                titles.append(item.localizedTitle)
            }
            if titles.count >= 6 { break }
        }
        return titles
    }

    public func genres(for category: MediaProjectType?, language: String) async -> [String] {
        let cacheKey = "genres:\(category?.rawValue ?? "all"):\(language)"
        if let cached = await cache.load(key: cacheKey, maxAge: 24 * 3600, as: [String].self) {
            return cached
        }

        var set: Set<String> = []
        let includeAnime = category == nil || category == .anime || category == .animeMovie || category == .special
        let includeTMDB = category != .anime && category != .animeMovie && category != .special

        if includeAnime, let aniGenres = try? await aniList.genres() {
            set.formUnion(aniGenres)
        }
        if includeTMDB, SecretsProvider.tmdbCredential() != nil {
            if let movieGenres = try? await tmdb.movieGenres(language: language) {
                set.formUnion(movieGenres.map(\.name))
            }
            if let tvGenres = try? await tmdb.tvGenres(language: language) {
                set.formUnion(tvGenres.map(\.name))
            }
        }
        if set.isEmpty {
            set = Set(TMDBMapper.genreNamesByID.values)
        }

        let sorted = set.sorted()
        await cache.store(sorted, forKey: cacheKey)
        return sorted
    }

    public func randomPick(criteria: CatalogFilterCriteria, language: String) async throws -> MediaItem? {
        let randomPage = Int.random(in: 1...8)
        let pageResult = try await discover(criteria: criteria, page: randomPage, language: language)
        if let picked = pageResult.items.randomElement() {
            return picked
        }
        let fallback = try await discover(criteria: criteria, page: 1, language: language)
        return fallback.items.randomElement()
    }

    private func fetchRecentlyAdded(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.status = "RELEASING"
            p.sort = ["START_DATE_DESC"]
            p.perPage = 12
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()

        async let tmdbMovies: [MediaItem] = hasTMDB
            ? ((try? await tmdb.nowPlayingMovies(page: 1, language: language)) ?? [])
            : []
        async let tmdbTV: [MediaItem] = hasTMDB
            ? ((try? await tmdb.onTheAirTV(page: 1, language: language)) ?? [])
            : []

        let combined = await Array(tmdbMovies.prefix(10)) + Array(tmdbTV.prefix(10)) + aniTask
        return MediaMerger.merge(combined)
    }

    private func fetchUpcoming(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.status = "NOT_YET_RELEASED"
            p.sort = ["POPULARITY_DESC"]
            p.perPage = 14
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let tmdbUpcoming: [MediaItem] = hasTMDB
            ? ((try? await tmdb.upcomingMovies(page: 1, language: language)) ?? [])
            : []

        return MediaMerger.merge(await tmdbUpcoming + aniTask)
    }

    private func fetchTopRated(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.sort = ["SCORE_DESC"]
            p.perPage = 14
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let tmdbMovies: [MediaItem] = hasTMDB
            ? ((try? await tmdb.topRatedMovies(page: 1, language: language)) ?? [])
            : []
        async let tmdbTV: [MediaItem] = hasTMDB
            ? ((try? await tmdb.topRatedTV(page: 1, language: language)) ?? [])
            : []

        let merged = MediaMerger.merge(await tmdbMovies + tmdbTV + aniTask)
        return merged.sorted { $0.displayRating > $1.displayRating }
    }
}
