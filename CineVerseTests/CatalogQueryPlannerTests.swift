import Foundation
import Testing
@testable import CineVerse

@Suite("Catalog Query Planner")
struct CatalogQueryPlannerTests {
    @Test func plansCategorySpecificProviderRequests() {
        var animeCriteria = CatalogFilterCriteria()
        animeCriteria.selectedCategory = .anime
        let animeReqs = CatalogQueryPlanner.planRequests(
            criteria: animeCriteria,
            page: 1,
            language: "en-US",
            hasTMDBCredential: true
        )
        #expect(animeReqs.count == 1)
        if case .aniList(let params) = animeReqs.first {
            #expect(params.formats == ["TV", "TV_SHORT", "ONA"])
        } else {
            Issue.record("Expected AniList request for .anime category")
        }

        var dramaCriteria = CatalogFilterCriteria()
        dramaCriteria.selectedCategory = .drama
        let dramaReqs = CatalogQueryPlanner.planRequests(
            criteria: dramaCriteria,
            page: 1,
            language: "en-US",
            hasTMDBCredential: true
        )
        if case .tmdbTV(let params, _) = dramaReqs.first {
            #expect(params.withGenres.contains(18))
            #expect(params.withoutGenres.contains(16))
            #expect(params.originCountry == "KR|CN|TW|TH|JP")
        } else {
            Issue.record("Expected TMDB TV request for .drama category")
        }
    }

    @Test func fallsBackToTVMazeWhenTMDBKeyMissingForTVSeries() {
        var tvCriteria = CatalogFilterCriteria()
        tvCriteria.selectedCategory = .tvSeries
        let reqs = CatalogQueryPlanner.planRequests(
            criteria: tvCriteria,
            page: 1,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(reqs.count == 1)
        if case .tvMazeIndex(let page) = reqs.first {
            #expect(page == 1)
        } else {
            Issue.record("Expected TVmaze fallback when TMDB key is missing")
        }
    }

    @Test func plansKeyFreeITunesCatalogForMoviesAndCartoonsWithoutTMDB() {
        var movieCriteria = CatalogFilterCriteria()
        movieCriteria.selectedCategory = .movie
        let movieReqs = CatalogQueryPlanner.planRequests(
            criteria: movieCriteria,
            page: 2,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(movieReqs.count == 1)
        if case .iTunesCategory(let cat, let page) = movieReqs.first {
            #expect(cat == .movie)
            #expect(page == 2)
        } else {
            Issue.record("Expected iTunes movie catalog request when TMDB key is absent")
        }

        var cartoonCriteria = CatalogFilterCriteria()
        cartoonCriteria.selectedCategory = .cartoonMovie
        let cartoonReqs = CatalogQueryPlanner.planRequests(
            criteria: cartoonCriteria,
            page: 1,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(cartoonReqs.count == 1)
        if case .iTunesCategory(let cat, _) = cartoonReqs.first {
            #expect(cat == .cartoonMovie)
        } else {
            Issue.record("Expected iTunes cartoonMovie request when TMDB key is absent")
        }
    }

    @Test func postFilterHandlesOriginalTitleOnlyAndMinSeasons() {
        let items = [
            MediaItem(
                id: "tmdb:tv:1",
                primarySource: .tmdb,
                projectType: .tvSeries,
                localizedTitle: "Attack on Titan",
                originalTitle: "Shingeki no Kyojin",
                synopsis: "",
                releaseYear: 2013,
                countryOfOrigin: "JP",
                originalLanguage: "ja",
                genres: ["Action"],
                durationMinutes: 24,
                totalSeasons: 4,
                totalEpisodes: 88,
                ratings: MultiSourceRatings(tmdbScore: 8.7)
            ),
            MediaItem(
                id: "tmdb:tv:2",
                primarySource: .tmdb,
                projectType: .tvSeries,
                localizedTitle: "Short Mini",
                originalTitle: "Short Mini",
                synopsis: "",
                releaseYear: 2022,
                countryOfOrigin: "US",
                originalLanguage: "en",
                genres: ["Drama"],
                durationMinutes: 45,
                totalSeasons: 1,
                totalEpisodes: 6,
                ratings: MultiSourceRatings(tmdbScore: 7.2)
            )
        ]

        var criteria = CatalogFilterCriteria()
        criteria.minSeasonsCount = 3
        criteria.searchByOriginalTitleOnly = true

        let filtered = CatalogQueryPlanner.postFilterAndSort(
            items: items,
            criteria: criteria,
            query: "Shingeki"
        )
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "tmdb:tv:1")
    }
}
