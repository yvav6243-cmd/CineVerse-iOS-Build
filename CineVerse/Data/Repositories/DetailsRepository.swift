import Foundation

public protocol DetailsRepositoryProtocol: Sendable {
    func details(for reference: MediaReference, language: String, watchRegion: String, offlineSnapshot: MediaItem?) async throws -> MediaItem
    func season(for reference: MediaReference, seasonNumber: Int, language: String, defaultDuration: Int) async throws -> MediaSeason
    func similarItems(for item: MediaItem, language: String) async -> [MediaItem]
}

public final class DetailsRepository: DetailsRepositoryProtocol, @unchecked Sendable {
    private let tmdb: TMDBServiceProtocol
    private let aniList: AniListServiceProtocol
    private let tvMaze: TVMazeServiceProtocol
    private let jikan: JikanServiceProtocol
    private let iTunes: ITunesCatalogServiceProtocol
    private let cache: ResponseDiskCache

    private let cacheTTL: TimeInterval = 4 * 3600

    public init(
        tmdb: TMDBServiceProtocol,
        aniList: AniListServiceProtocol,
        tvMaze: TVMazeServiceProtocol,
        jikan: JikanServiceProtocol,
        iTunes: ITunesCatalogServiceProtocol = ITunesCatalogService(httpClient: URLSessionHTTPClient()),
        cache: ResponseDiskCache
    ) {
        self.tmdb = tmdb
        self.aniList = aniList
        self.tvMaze = tvMaze
        self.jikan = jikan
        self.iTunes = iTunes
        self.cache = cache
    }

    public func details(
        for reference: MediaReference,
        language: String,
        watchRegion: String,
        offlineSnapshot: MediaItem?
    ) async throws -> MediaItem {
        let cacheKey = "details:\(reference.id):\(language):\(watchRegion)"
        if let cached = await cache.load(key: cacheKey, maxAge: cacheTTL, as: MediaItem.self) {
            return cached
        }

        do {
            var item: MediaItem
            switch (reference.provider, reference.kind) {
            case (.tmdb, .movie):
                let res = try await tmdb.movieDetails(id: reference.providerID, language: language, watchRegion: watchRegion)
                item = res.item
            case (.tmdb, .tv), (.tmdb, .anime):
                let res = try await tmdb.tvDetails(id: reference.providerID, language: language, watchRegion: watchRegion)
                item = res.item
                if let imdbID = res.imdbID,
                   let tvMazeMatch = try? await tvMaze.lookupByIMDB(imdbID) {
                    item.ratings.tvMazeScore = tvMazeMatch.rating
                }
            case (.aniList, _):
                guard let intID = Int(reference.providerID) else {
                    throw NetworkError.invalidURL
                }
                let res = try await aniList.mediaDetails(id: intID)
                item = res.item
                if let malID = res.malID, item.projectType.isEpisodic,
                   let jikanEpisodes = try? await jikan.episodes(
                    malID: malID,
                    animeID: reference.providerID,
                    defaultDuration: item.durationMinutes
                   ),
                   !jikanEpisodes.isEmpty {
                    let mergedEpisodes = mergeAnimeEpisodes(existing: item.seasons.first?.episodes ?? [], jikan: jikanEpisodes)
                    if !item.seasons.isEmpty {
                        item.seasons[0].episodes = mergedEpisodes
                    } else {
                        item.seasons = [
                            MediaSeason(
                                id: "anilist:anime:\(reference.providerID):s1",
                                seasonNumber: 1,
                                title: "Episodes",
                                episodeCount: mergedEpisodes.count,
                                posterURL: item.posterURL,
                                releaseYear: item.releaseYear,
                                episodes: mergedEpisodes
                            )
                        ]
                    }
                }
            case (.tvMaze, _):
                item = try await tvMaze.showDetails(id: reference.providerID)
            case (.openCinema, _):
                if let resolved = try await iTunes.lookupDetails(providerID: reference.providerID) {
                    item = resolved
                } else if let offlineSnapshot {
                    return offlineSnapshot
                } else {
                    throw NetworkError.invalidURL
                }
            }

            await cache.store(item, forKey: cacheKey)
            return item
        } catch {
            if let stale = await cache.loadEvenIfStale(key: cacheKey, as: MediaItem.self) {
                return stale
            }
            if let offlineSnapshot {
                return offlineSnapshot
            }
            throw error
        }
    }

    public func season(
        for reference: MediaReference,
        seasonNumber: Int,
        language: String,
        defaultDuration: Int
    ) async throws -> MediaSeason {
        let cacheKey = "season:\(reference.id):s\(seasonNumber):\(language)"
        if let cached = await cache.load(key: cacheKey, maxAge: cacheTTL, as: MediaSeason.self) {
            return cached
        }

        let season: MediaSeason
        switch reference.provider {
        case .tmdb:
            season = try await tmdb.tvSeason(
                tvID: reference.providerID,
                seasonNumber: seasonNumber,
                language: language,
                defaultDuration: defaultDuration
            )
        case .tvMaze:
            let show = try await tvMaze.showDetails(id: reference.providerID)
            if let match = show.seasons.first(where: { $0.seasonNumber == seasonNumber }) {
                season = match
            } else {
                throw NetworkError.http(statusCode: 404, message: "Season not found")
            }
        case .aniList, .openCinema:
            let full = try await details(for: reference, language: language, watchRegion: "US", offlineSnapshot: nil)
            if let match = full.seasons.first(where: { $0.seasonNumber == seasonNumber }) {
                season = match
            } else {
                throw NetworkError.http(statusCode: 404, message: "Season not found")
            }
        }

        await cache.store(season, forKey: cacheKey)
        return season
    }

    public func similarItems(for item: MediaItem, language: String) async -> [MediaItem] {
        let refs = item.similarProjectIDs.prefix(10).compactMap(MediaReference.init(id:))
        guard !refs.isEmpty else { return [] }

        var results: [MediaItem] = []
        await withTaskGroup(of: MediaItem?.self) { group in
            for ref in refs {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return try? await self.details(for: ref, language: language, watchRegion: "US", offlineSnapshot: nil)
                }
            }
            for await resolved in group {
                if let resolved {
                    results.append(resolved)
                }
            }
        }
        return results
    }

    private func mergeAnimeEpisodes(existing: [MediaEpisode], jikan: [MediaEpisode]) -> [MediaEpisode] {
        let existingByNum = Dictionary(uniqueKeysWithValues: existing.map { ($0.episodeNumber, $0) })
        return jikan.map { ep in
            let fallback = existingByNum[ep.episodeNumber]
            return MediaEpisode(
                id: ep.id,
                seasonNumber: 1,
                episodeNumber: ep.episodeNumber,
                title: ep.title,
                originalTitle: ep.originalTitle,
                synopsis: ep.synopsis,
                durationMinutes: ep.durationMinutes,
                airDate: ep.airDate,
                stillImageURL: fallback?.stillImageURL
            )
        }
    }
}
