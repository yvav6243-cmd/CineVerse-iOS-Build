import Foundation
import SwiftData
import Testing
@testable import CineVerse

@Suite("Category 9: Tracker, Playback Progress & Analytics")
struct TrackerServiceTests {
    private func makeTestSeries() -> MediaItem {
        let ep1 = MediaEpisode(id: "s1e1", seasonNumber: 1, episodeNumber: 1, title: "One", synopsis: "", durationMinutes: 24)
        let ep2 = MediaEpisode(id: "s2e1", seasonNumber: 2, episodeNumber: 1, title: "Two", synopsis: "", durationMinutes: 24)
        return MediaItem(
            id: "tmdb:tv:500",
            primarySource: .tmdb,
            projectType: .tvSeries,
            localizedTitle: "Test Show",
            originalTitle: "Test Show",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Drama", "Sci-Fi"],
            durationMinutes: 24,
            totalSeasons: 2,
            totalEpisodes: 2,
            ratings: MultiSourceRatings(tmdbScore: 8.0),
            seasons: [
                MediaSeason(id: "s1", seasonNumber: 1, title: "Season 1", episodeCount: 1, episodes: [ep1]),
                MediaSeason(id: "s2", seasonNumber: 2, title: "Season 2", episodeCount: 1, episodes: [ep2])
            ]
        )
    }

    @MainActor
    @Test func transitionsStatusAndFindsNextEpisodeAcrossSeasons() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let libRepo = LibraryRepository(modelContext: context)
        let progRepo = ProgressRepository(modelContext: context, libraryRepository: libRepo)
        let tracker = TrackerService(libraryRepository: libRepo, progressRepository: progRepo)
        let series = makeTestSeries()
        let ep1 = try #require(series.seasons.first?.episodes.first)

        tracker.markEpisodeWatched(item: series, season: 1, episode: 1, episodeTitle: "One", durationMinutes: 24)
        let entryAfterOne = try #require(libRepo.entry(for: series.id))
        #expect(entryAfterOne.status == .watching)

        let next = tracker.nextEpisode(after: ep1, in: series)
        #expect(next?.id == "s2e1")

        tracker.markEpisodeWatched(item: series, season: 2, episode: 1, episodeTitle: "Two", durationMinutes: 24)
        let entryAfterAll = try #require(libRepo.entry(for: series.id))
        #expect(entryAfterAll.status == .completed)
    }

    @MainActor
    @Test func nextEpisodeReturnsNilAtFinalEpisodeOfFinalSeason() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let progRepo = ProgressRepository(modelContext: container.mainContext, libraryRepository: libRepo)
        let tracker = TrackerService(libraryRepository: libRepo, progressRepository: progRepo)
        let series = makeTestSeries()
        let lastEp = try #require(series.seasons.last?.episodes.last)

        #expect(tracker.nextEpisode(after: lastEp, in: series) == nil)
    }

    @MainActor
    @Test func savesPartialPlaybackPositionAndSurfacesInContinueWatching() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let progRepo = ProgressRepository(modelContext: container.mainContext, libraryRepository: libRepo)
        let movie = MediaItem(
            id: "tmdb:movie:901", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Halfway Film", originalTitle: "Halfway Film", synopsis: "",
            releaseYear: 2025, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Action"], durationMinutes: 120, ratings: MultiSourceRatings(tmdbScore: 8.0)
        )

        _ = progRepo.savePlaybackPosition(
            item: movie, season: 0, episode: 0, episodeTitle: movie.localizedTitle,
            positionSeconds: 1800, durationSeconds: 7200, sourceID: "src-1"
        )

        let cw = progRepo.continueWatchingItems()
        #expect(cw.count == 1)
        #expect(cw.first?.entry.mediaID == "tmdb:movie:901")
        #expect(abs((cw.first?.progress.fraction ?? 0) - 0.25) < 0.01)
    }

    @MainActor
    @Test func togglesWatchlistAndFavoriteFlagsIndependently() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let item = makeTestSeries()

        let addedWatchlist = libRepo.toggleWatchlist(for: item)
        #expect(addedWatchlist == true)
        #expect(libRepo.entry(for: item.id)?.inWatchlist == true)

        let addedFav = libRepo.toggleFavorite(for: item)
        #expect(addedFav == true)
        #expect(libRepo.favorites().count == 1)

        let removedWatchlist = libRepo.toggleWatchlist(for: item)
        #expect(removedWatchlist == false)
        #expect(libRepo.entry(for: item.id)?.inWatchlist == false)
        #expect(libRepo.favorites().count == 1)
    }

    @MainActor
    @Test func persistsAndUpdatesPersonalNotesAndRatings() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let item = makeTestSeries()

        libRepo.setPersonalRating(9.2, for: item)
        libRepo.setNotes("Masterpiece pacing in finale.", for: item)

        let entry = try #require(libRepo.entry(for: item.id))
        #expect(entry.personalRating == 9.2)
        #expect(entry.notes == "Masterpiece pacing in finale.")
    }

    @MainActor
    @Test func customCollectionsCreateAddRemoveAndDeleteCleanly() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let colRepo = CollectionsRepository(modelContext: container.mainContext)
        let item = makeTestSeries()

        let created = colRepo.createCollection(name: "Weekend Marathon", symbolName: "sparkles.tv")
        colRepo.add(item: item, to: created.id)
        #expect(colRepo.collection(id: created.id)?.items.count == 1)
        #expect(colRepo.collectionIDs(containing: item.id).contains(created.id))

        colRepo.remove(mediaID: item.id, from: created.id)
        #expect(colRepo.collection(id: created.id)?.items.isEmpty == true)

        colRepo.deleteCollection(id: created.id)
        #expect(colRepo.allCollections().isEmpty)
    }

    @MainActor
    @Test func searchHistoryDeduplicatesQueriesCaseInsensitivelyAndClears() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let historyRepo = SearchHistoryRepository(modelContext: container.mainContext)

        historyRepo.saveQuery("Interstellar")
        historyRepo.saveQuery("interstellar")
        historyRepo.saveQuery("Dune")

        let recent = historyRepo.recentQueries(limit: 10)
        #expect(recent.count == 2)
        #expect(recent.first?.query == "Dune")

        historyRepo.clearAll()
        #expect(historyRepo.recentQueries(limit: 10).isEmpty)
    }

    @Test func analyticsCalculatorComputesHoursCategoriesGenresAndAverageScore() {
        let e1 = LibraryEntryRecord(
            mediaID: "tmdb:movie:1", title: "Film A", originalTitle: "Film A",
            projectTypeRaw: MediaProjectType.movie.rawValue, genres: ["Sci-Fi", "Drama"],
            releaseYear: 2024, statusRaw: WatchTrackingStatus.completed.rawValue,
            personalRating: 9.0
        )
        let e2 = LibraryEntryRecord(
            mediaID: "anilist:anime:2", title: "Anime B", originalTitle: "Anime B",
            projectTypeRaw: MediaProjectType.anime.rawValue, genres: ["Sci-Fi", "Action"],
            releaseYear: 2024, statusRaw: WatchTrackingStatus.completed.rawValue,
            personalRating: 8.0, totalEpisodes: 12, totalSeasons: 1
        )
        let p1 = PlaybackProgressRecord(
            mediaID: "anilist:anime:2", season: 1, episode: 1, episodeTitle: "Ep 1",
            positionSeconds: 1440, durationSeconds: 1440, isWatched: true
        )
        let h1 = WatchHistoryRecord(
            mediaID: "tmdb:movie:1", title: "Film A",
            projectTypeRaw: MediaProjectType.movie.rawValue,
            genres: ["Sci-Fi", "Drama"], minutesWatched: 120
        )
        let h2 = WatchHistoryRecord(
            mediaID: "anilist:anime:2", title: "Anime B",
            projectTypeRaw: MediaProjectType.anime.rawValue,
            genres: ["Sci-Fi", "Action"], season: 1, episode: 1, minutesWatched: 30
        )

        let snap = AnalyticsCalculator.calculate(entries: [e1, e2], progress: [p1], history: [h1, h2])
        #expect(snap.totalProjectsWatched == 2)
        #expect(snap.totalMoviesWatched == 1)
        #expect(snap.totalAnimeWatched == 1)
        #expect(snap.totalEpisodesWatched == 1)
        #expect(abs(snap.totalHoursWatched - 2.5) < 0.001)
        #expect(abs(snap.averagePersonalScore - 8.5) < 0.001)
        #expect(snap.topGenres.first?.genre == "Sci-Fi")
    }

    @Test func dailyActivityGeneratesExactRequestedDayWindow() {
        let h = WatchHistoryRecord(
            mediaID: "tmdb:movie:1", title: "Today Film",
            projectTypeRaw: MediaProjectType.movie.rawValue,
            genres: ["Drama"], minutesWatched: 95, watchedAt: Date()
        )
        let points = AnalyticsCalculator.dailyActivity(from: [h], days: 14)
        #expect(points.count == 14)
        #expect(points.last?.minutesWatched == 95)
    }
}
