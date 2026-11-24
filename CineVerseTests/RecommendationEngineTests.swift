import Foundation
import Testing
@testable import CineVerse

@Suite("Recommendation Engine")
struct RecommendationEngineTests {
    @Test func ranksSciFiHigherThanHorrorBasedOnTasteProfile() {
        let historyEntries = [
            TasteEntrySnapshot(
                mediaID: "tmdb:movie:1",
                projectType: .movie,
                genres: ["Sci-Fi", "Adventure"],
                status: .completed,
                isFavorite: true,
                personalRating: 9.5
            ),
            TasteEntrySnapshot(
                mediaID: "tmdb:movie:2",
                projectType: .movie,
                genres: ["Horror"],
                status: .dropped,
                isFavorite: false,
                personalRating: 2.0
            )
        ]

        let profile = RecommendationScorer.buildProfile(fromSnapshots: historyEntries)

        let sciFiCandidate = MediaItem(
            id: "tmdb:movie:100",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Cosmic Odyssey",
            originalTitle: "Cosmic Odyssey",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Sci-Fi", "Adventure"],
            durationMinutes: 140,
            ratings: MultiSourceRatings(tmdbScore: 8.2),
            popularityScore: 90
        )

        let horrorCandidate = MediaItem(
            id: "tmdb:movie:101",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Midnight Scare",
            originalTitle: "Midnight Scare",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Horror"],
            durationMinutes: 95,
            ratings: MultiSourceRatings(tmdbScore: 8.2),
            popularityScore: 90
        )

        let alreadyWatched = MediaItem(
            id: "tmdb:movie:1",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Watched Film",
            originalTitle: "Watched Film",
            synopsis: "",
            releaseYear: 2020,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Sci-Fi"],
            durationMinutes: 120,
            ratings: MultiSourceRatings(tmdbScore: 9.0)
        )

        let ranked = RecommendationScorer.rank(
            candidates: [horrorCandidate, alreadyWatched, sciFiCandidate],
            profile: profile
        )

        #expect(ranked.count == 2)
        #expect(ranked.first?.id == "tmdb:movie:100")
    }
}
