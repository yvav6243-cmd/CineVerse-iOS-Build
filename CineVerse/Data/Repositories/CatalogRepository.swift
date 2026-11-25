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
    private let iTunes: ITunesCatalogServiceProtocol
    private let cache: ResponseDiskCache
    private let playableMediaIDsProvider: (@Sendable () async -> Set<String>)?

    private let cacheTTL: TimeInterval = 6 * 3600

    public init(
        tmdb: TMDBServiceProtocol,
        aniList: AniListServiceProtocol,
        tvMaze: TVMazeServiceProtocol,
        iTunes: ITunesCatalogServiceProtocol = ITunesCatalogService(httpClient: URLSessionHTTPClient()),
        cache: ResponseDiskCache,
        playableMediaIDsProvider: (@Sendable () async -> Set<String>)? = nil
    ) {
        self.tmdb = tmdb
        self.aniList = aniList
        self.tvMaze = tvMaze
        self.iTunes = iTunes
        self.cache = cache
        self.playableMediaIDsProvider = playableMediaIDsProvider
    }

    public func homeFeed(_ section: HomeSectionType, language: String) async throws -> [MediaItem] {
        let hasTMDB = SecretsProvider.tmdbCredential() != nil
        let cacheKey = "home:\(section.rawValue):\(language):tmdb=\(hasTMDB)"
        if let cached = await cache.load(key: cacheKey, maxAge: cacheTTL, as: [MediaItem].self) {
            return cached
        }

        do {
            let items: [MediaItem]
            switch section {
            case .trendingNow:
                items = try await fetchTrendingNow(language: language, hasTMDB: hasTMDB)
            case .newEpisodes:
                items = try await fetchNewEpisodes(language: language, hasTMDB: hasTMDB)
            case .recentlyAdded:
                items = try await fetchRecentlyAdded(language: language, hasTMDB: hasTMDB)
            case .trendingMovies:
                if hasTMDB {
                    let tmdbMovies = try await tmdb.trendingMovies(page: 1, language: language)
                    items = MediaMerger.merge(iTunes.openCinemaShowcase().filter { !$0.projectType.isEpisodic } + tmdbMovies)
                } else {
                    let charts = try await iTunes.topMovies(genreID: nil, limit: 50)
                    items = MediaMerger.merge(iTunes.openCinemaShowcase().filter { !$0.projectType.isEpisodic } + charts)
                }
            case .popularAnime:
                var params = AniListSearchParameters()
                params.sort = ["TRENDING_DESC"]
                params.perPage = 25
                items = try await aniList.fetchMediaPage(params).items
            case .popularTVShows:
                if hasTMDB {
                    items = try await tmdb.popularTV(page: 1, language: language)
                } else {
                    let p1 = try await tvMaze.showIndex(page: 1)
                    let p2 = (try? await tvMaze.showIndex(page: 2)) ?? []
                    items = Array(MediaMerger.merge(p1 + p2).prefix(45))
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

        if requests.isEmpty {
            return CatalogPage(items: [], hasMore: false)
        }

        var collected: [MediaItem] = []
        var anyHasMore = false
        var excludeJapanese = criteria.selectedCategory == .cartoonSeries || criteria.selectedCategory == .cartoonMovie

        try await withThrowingTaskGroup(of: (items: [MediaItem], hasMore: Bool, excludeJa: Bool).self) { group in
            for request in requests {
                group.addTask { [tmdb, aniList, tvMaze, iTunes] in
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
                        return (res, !res.isEmpty, false)
                    case .iTunesCategory(let cat, let pg):
                        let res = try await iTunes.moviesByCategory(cat, page: pg)
                        let moreAvailable = cat == .movie ? (pg < 8 && !res.isEmpty) : false
                        return (res, moreAvailable, cat == .cartoonMovie)
                    }
                }
            }

            for try await part in group {
                collected.append(contentsOf: part.items)
                if part.hasMore { anyHasMore = true }
                if part.excludeJa { excludeJapanese = true }
            }
        }

        if page == 1 {
            collected.insert(contentsOf: iTunes.openCinemaShowcase(), at: 0)
        }
        let userPlayable = await (playableMediaIDsProvider?() ?? [])
        let merged = MediaMerger.merge(collected)
        let processed = CatalogQueryPlanner.postFilterAndSort(
            items: merged,
            criteria: criteria,
            excludeJapaneseForCartoons: excludeJapanese,
            userPlayableMediaIDs: userPlayable
        )
        return CatalogPage(items: processed, hasMore: anyHasMore && !criteria.onlyAvailableToWatch)
    }

    public func search(query: String, criteria: CatalogFilterCriteria, page: Int, language: String) async throws -> CatalogPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await discover(criteria: criteria, page: page, language: language)
        }

        let hasTMDB = SecretsProvider.tmdbCredential() != nil
        var allItems: [MediaItem] = []
        var anyHasMore = false

        if page == 1 {
            let localOpenMatches = iTunes.openCinemaShowcase().filter {
                PlayableCatalogEvaluator.matchesSearchQuery($0, query: trimmed)
            }
            allItems.append(contentsOf: localOpenMatches)
        }

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
                group.addTask { [aniList] in
                    let entityItems = (try? await aniList.searchEntities(query: trimmed)) ?? []
                    return (entityItems, false)
                }
                group.addTask { [iTunes] in
                    let movies = (try? await iTunes.searchMovies(query: trimmed, limit: 35)) ?? []
                    return (movies, false)
                }
                group.addTask { [tvMaze] in
                    let shows = (try? await tvMaze.searchShows(query: trimmed)) ?? []
                    return (shows, false)
                }
                if let exactYear = Int(trimmed), (1920...2030).contains(exactYear) {
                    group.addTask { [aniList] in
                        var p = AniListSearchParameters()
                        p.yearFrom = exactYear
                        p.yearTo = exactYear
                        p.perPage = 16
                        return (try? await aniList.fetchMediaPage(p)) ?? ([], false)
                    }
                }
            }

            for await result in group {
                allItems.append(contentsOf: result.items)
                if result.hasMore { anyHasMore = true }
            }
        }

        let userPlayable = await (playableMediaIDsProvider?() ?? [])
        let merged = MediaMerger.merge(allItems)
        let filtered = CatalogQueryPlanner.postFilterAndSort(
            items: merged,
            criteria: criteria,
            query: trimmed,
            userPlayableMediaIDs: userPlayable
        )
        return CatalogPage(items: filtered, hasMore: anyHasMore && !criteria.onlyAvailableToWatch)
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

        async let iTunesTask: [MediaItem] = (try? await iTunes.searchMovies(query: trimmed, limit: 6)) ?? []

        async let tmdbTask: [MediaItem] = {
            guard SecretsProvider.tmdbCredential() != nil else { return [] }
            return (try? await tmdb.searchMulti(query: trimmed, page: 1, language: language).items) ?? []
        }()

        let combined = await tmdbTask + iTunesTask + aniTask
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

    private func fetchTrendingNow(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        let openShowcase = iTunes.openCinemaShowcase()
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.sort = ["TRENDING_DESC"]
            p.perPage = 10
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let movieTask: [MediaItem] = hasTMDB
            ? ((try? await tmdb.trendingMovies(page: 1, language: language)) ?? [])
            : ((try? await iTunes.topMovies(genreID: nil, limit: 16)) ?? [])
        async let tvTask: [MediaItem] = hasTMDB
            ? ((try? await tmdb.popularTV(page: 1, language: language)) ?? [])
            : ((try? await tvMaze.showIndex(page: 1)) ?? [])

        let combined = openShowcase + Array((await movieTask).prefix(10)) + (await aniTask) + Array((await tvTask).prefix(8))
        return MediaMerger.merge(combined)
    }

    private func fetchNewEpisodes(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        let openSeries = iTunes.openCinemaShowcase().filter { $0.projectType.isEpisodic }
        async let airingAnime: [MediaItem] = {
            var p = AniListSearchParameters()
            p.status = "RELEASING"
            p.sort = ["POPULARITY_DESC"]
            p.perPage = 16
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let airingTV: [MediaItem] = hasTMDB
            ? ((try? await tmdb.onTheAirTV(page: 1, language: language)) ?? [])
            : (((try? await tvMaze.showIndex(page: 1)) ?? []).filter { $0.releaseStatus == .releasing })

        return MediaMerger.merge(openSeries + (await airingAnime) + Array((await airingTV).prefix(14)))
    }

    private func fetchRecentlyAdded(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.status = "RELEASING"
            p.sort = ["START_DATE_DESC"]
            p.perPage = 12
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()

        async let movieTask: [MediaItem] = hasTMDB
            ? ((try? await tmdb.nowPlayingMovies(page: 1, language: language)) ?? [])
            : ((try? await iTunes.topMovies(genreID: nil, limit: 20)) ?? [])
        async let tvTask: [MediaItem] = hasTMDB
            ? ((try? await tmdb.onTheAirTV(page: 1, language: language)) ?? [])
            : ((try? await tvMaze.showIndex(page: 1)) ?? [])

        let combined = await Array(movieTask.prefix(14)) + Array(tvTask.prefix(12)) + aniTask
        return MediaMerger.merge(combined)
    }

    private func fetchUpcoming(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.status = "NOT_YET_RELEASED"
            p.sort = ["POPULARITY_DESC"]
            p.perPage = 16
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let movieUpcoming: [MediaItem] = hasTMDB
            ? ((try? await tmdb.upcomingMovies(page: 1, language: language)) ?? [])
            : (((try? await iTunes.topMovies(genreID: 4401, limit: 30)) ?? []).filter { $0.releaseYear >= 2025 })

        return MediaMerger.merge(await movieUpcoming + aniTask)
    }

    private func fetchTopRated(language: String, hasTMDB: Bool) async throws -> [MediaItem] {
        async let aniTask: [MediaItem] = {
            var p = AniListSearchParameters()
            p.sort = ["SCORE_DESC"]
            p.perPage = 14
            return (try? await aniList.fetchMediaPage(p).items) ?? []
        }()
        async let movieTop: [MediaItem] = hasTMDB
            ? ((try? await tmdb.topRatedMovies(page: 1, language: language)) ?? [])
            : (iTunes.openCinemaShowcase() + ((try? await iTunes.topMovies(genreID: 4406, limit: 25)) ?? []))
        async let tvTop: [MediaItem] = hasTMDB
            ? ((try? await tmdb.topRatedTV(page: 1, language: language)) ?? [])
            : (((try? await tvMaze.showIndex(page: 1)) ?? []).filter { $0.displayRating >= 8.2 })

        let merged = MediaMerger.merge(await movieTop + Array(tvTop.prefix(15)) + aniTask)
        return merged.sorted { $0.displayRating > $1.displayRating }
    }
}
