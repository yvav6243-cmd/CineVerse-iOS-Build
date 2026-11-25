import Foundation
import Testing
@testable import CineVerse

@Suite("Category 10C: Recommendation Engine & Taste Profiling")
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

    @Test func coldStartEmptyProfileRanksPurelyByQualityAndPopularity() {
        let profile = RecommendationScorer.buildProfile(fromSnapshots: [])
        let low = MediaItem(
            id: "1", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Low", originalTitle: "Low", synopsis: "",
            releaseYear: 2023, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama"], durationMinutes: 95, ratings: MultiSourceRatings(tmdbScore: 5.5), popularityScore: 20
        )
        let high = MediaItem(
            id: "2", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "High", originalTitle: "High", synopsis: "",
            releaseYear: 2024, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama"], durationMinutes: 125, ratings: MultiSourceRatings(tmdbScore: 8.9), popularityScore: 800
        )

        let ranked = RecommendationScorer.rank(candidates: [low, high], profile: profile)
        #expect(ranked.map(\.id) == ["2", "1"])
    }

    @Test func boostsPreferredProjectCategoryFromWatchHistory() {
        let animeLover = [
            TasteEntrySnapshot(mediaID: "a1", projectType: .anime, genres: ["Fantasy"], status: .completed, isFavorite: true, personalRating: 9.5),
            TasteEntrySnapshot(mediaID: "a2", projectType: .anime, genres: ["Fantasy"], status: .watching, isFavorite: true, personalRating: 9.0)
        ]
        let profile = RecommendationScorer.buildProfile(fromSnapshots: animeLover)

        let animeCandidate = MediaItem(
            id: "cand-anime", primarySource: .aniList, projectType: .anime,
            localizedTitle: "Mage Quest", originalTitle: "Mage Quest", synopsis: "",
            releaseYear: 2025, countryOfOrigin: "JP", originalLanguage: "ja",
            genres: ["Fantasy"], durationMinutes: 24, ratings: MultiSourceRatings(aniListScore: 8.0), popularityScore: 100
        )
        let docCandidate = MediaItem(
            id: "cand-doc", primarySource: .tmdb, projectType: .documentary,
            localizedTitle: "Nature Doc", originalTitle: "Nature Doc", synopsis: "",
            releaseYear: 2025, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Documentary"], durationMinutes: 90, ratings: MultiSourceRatings(tmdbScore: 8.0), popularityScore: 100
        )

        let ranked = RecommendationScorer.rank(candidates: [docCandidate, animeCandidate], profile: profile)
        #expect(ranked.first?.id == "cand-anime")
    }

    @Test func deduplicatesIdenticalCandidateIDsDuringRanking() {
        let profile = RecommendationScorer.buildProfile(fromSnapshots: [])
        let item = MediaItem(
            id: "dup-1", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Dup", originalTitle: "Dup", synopsis: "",
            releaseYear: 2024, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Action"], durationMinutes: 110, ratings: MultiSourceRatings(tmdbScore: 7.8)
        )
        let ranked = RecommendationScorer.rank(candidates: [item, item], profile: profile)
        #expect(ranked.count <= 2)
        #expect(ranked.first?.id == "dup-1")
    }

    @Test func languageCatalogResolvesHumanReadableLanguageNames() {
        #expect(LanguageCatalog.displayName(forLanguageCode: "en").localizedCaseInsensitiveContains("english"))
        #expect(LanguageCatalog.displayName(forLanguageCode: "ja").localizedCaseInsensitiveContains("japan"))
        #expect(!LanguageCatalog.displayName(forLanguageCode: "ru").isEmpty)
    }
}
