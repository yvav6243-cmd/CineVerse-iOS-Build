import Foundation

public protocol CalendarRepositoryProtocol: Sendable {
    func upcomingEvents(from: Date, to: Date, watchRegion: String, language: String) async throws -> [PremiereEvent]
}

public final class CalendarRepository: CalendarRepositoryProtocol, @unchecked Sendable {
    private let aniList: AniListServiceProtocol
    private let tvMaze: TVMazeServiceProtocol
    private let tmdb: TMDBServiceProtocol
    private let cache: ResponseDiskCache

    public init(
        aniList: AniListServiceProtocol,
        tvMaze: TVMazeServiceProtocol,
        tmdb: TMDBServiceProtocol,
        cache: ResponseDiskCache
    ) {
        self.aniList = aniList
        self.tvMaze = tvMaze
        self.tmdb = tmdb
        self.cache = cache
    }

    public func upcomingEvents(
        from: Date,
        to: Date,
        watchRegion: String,
        language: String
    ) async throws -> [PremiereEvent] {
        let startKey = CineVerseDateFormatters.isoDateParser.string(from: from)
        let cacheKey = "calendar:\(startKey):\(watchRegion):\(language)"
        if let cached = await cache.load(key: cacheKey, maxAge: 2 * 3600, as: [PremiereEvent].self) {
            return cached
        }

        let calendar = Calendar.current
        var datesToFetch: [Date] = []
        var cursor = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: to)
        while cursor <= endDay && datesToFetch.count < 7 {
            datesToFetch.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var collected: [PremiereEvent] = []

        await withTaskGroup(of: [PremiereEvent].self) { group in
            group.addTask { [aniList] in
                (try? await aniList.airingSchedule(from: from, to: to, page: 1)) ?? []
            }

            for day in datesToFetch {
                group.addTask { [tvMaze] in
                    (try? await tvMaze.schedule(countryCode: watchRegion, date: day)) ?? []
                }
                group.addTask { [tvMaze] in
                    (try? await tvMaze.webSchedule(date: day)) ?? []
                }
            }

            if SecretsProvider.tmdbCredential() != nil {
                group.addTask { [tmdb] in
                    let movies = (try? await tmdb.upcomingMovies(page: 1, language: language)) ?? []
                    return movies.compactMap { movie in
                        guard let ref = movie.reference,
                              let date = movie.releaseDate,
                              date >= from && date <= to else {
                            return nil
                        }
                        return PremiereEvent(
                            id: "tmdb:air:\(movie.id)",
                            mediaReference: ref,
                            title: movie.localizedTitle,
                            episodeTitle: "Theatrical / Premiere Release",
                            posterURL: movie.posterURL,
                            date: date,
                            kind: movie.projectType,
                            source: .tmdb
                        )
                    }
                }
            }

            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }

        var seen: Set<String> = []
        let uniqueSorted = collected
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.date < $1.date }

        if !uniqueSorted.isEmpty {
            await cache.store(uniqueSorted, forKey: cacheKey)
        }
        return uniqueSorted
    }
}
