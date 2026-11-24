import Foundation
import SwiftData
import Testing
@testable import CineVerse

@Suite("Tracker Service")
struct TrackerServiceTests {
    @MainActor
    @Test func transitionsStatusAndFindsNextEpisodeAcrossSeasons() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let libRepo = LibraryRepository(modelContext: context)
        let progRepo = ProgressRepository(modelContext: context, libraryRepository: libRepo)
        let tracker = TrackerService(libraryRepository: libRepo, progressRepository: progRepo)

        let ep1 = MediaEpisode(id: "s1e1", seasonNumber: 1, episodeNumber: 1, title: "One", synopsis: "", durationMinutes: 24)
        let ep2 = MediaEpisode(id: "s2e1", seasonNumber: 2, episodeNumber: 1, title: "Two", synopsis: "", durationMinutes: 24)

        let series = MediaItem(
            id: "tmdb:tv:500",
            primarySource: .tmdb,
            projectType: .tvSeries,
            localizedTitle: "Test Show",
            originalTitle: "Test Show",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Drama"],
            durationMinutes: 24,
            totalSeasons: 2,
            totalEpisodes: 2,
            ratings: MultiSourceRatings(tmdbScore: 8.0),
            seasons: [
                MediaSeason(id: "s1", seasonNumber: 1, title: "Season 1", episodeCount: 1, episodes: [ep1]),
                MediaSeason(id: "s2", seasonNumber: 2, title: "Season 2", episodeCount: 1, episodes: [ep2])
            ]
        )

        tracker.markEpisodeWatched(item: series, season: 1, episode: 1, episodeTitle: "One", durationMinutes: 24)
        let entryAfterOne = try #require(libRepo.entry(for: series.id))
        #expect(entryAfterOne.status == .watching)

        let next = tracker.nextEpisode(after: ep1, in: series)
        #expect(next?.id == "s2e1")

        tracker.markEpisodeWatched(item: series, season: 2, episode: 1, episodeTitle: "Two", durationMinutes: 24)
        let entryAfterAll = try #require(libRepo.entry(for: series.id))
        #expect(entryAfterAll.status == .completed)
    }
}
