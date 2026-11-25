import Foundation
import Testing
@testable import CineVerse

@Suite("Category 6: Catalog Query Planner, Filtering & Sorting")
struct CatalogQueryPlannerTests {
    @Test func plansCategorySpecificProviderRequestsWithTMDBCredential() {
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

    @Test func plansMultiPageTVMazeForCartoonSeriesAndDocumentariesWithoutTMDB() {
        let cartoonSeriesReqs = CatalogQueryPlanner.planRequests(
            criteria: CatalogFilterCriteria(selectedCategory: .cartoonSeries),
            page: 2,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(cartoonSeriesReqs.count == 2)

        let docReqs = CatalogQueryPlanner.planRequests(
            criteria: CatalogFilterCriteria(selectedCategory: .documentary),
            page: 1,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(docReqs.count == 3)
    }

    @Test func plansCombinedMovieTVAndAnimeForAllCategoriesWithoutTMDB() {
        let allReqs = CatalogQueryPlanner.planRequests(
            criteria: CatalogFilterCriteria(selectedCategory: nil),
            page: 1,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(allReqs.count == 3)
    }

    @Test func plansSpecialCategoryIncludingOpenCinemaOnFirstPageOnly() {
        let page1 = CatalogQueryPlanner.planRequests(
            criteria: CatalogFilterCriteria(selectedCategory: .special),
            page: 1,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(page1.count == 2)

        let page2 = CatalogQueryPlanner.planRequests(
            criteria: CatalogFilterCriteria(selectedCategory: .special),
            page: 2,
            language: "en-US",
            hasTMDBCredential: false
        )
        #expect(page2.count == 1)
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

    @Test func postFilterExcludesJapaneseLanguageWhenCartoonFlagSet() {
        let jaAnim = MediaItem(
            id: "1", primarySource: .tvMaze, projectType: .cartoonSeries,
            localizedTitle: "JP Show", originalTitle: "JP Show", synopsis: "",
            releaseYear: 2023, countryOfOrigin: "JP", originalLanguage: "ja",
            genres: ["Animation"], durationMinutes: 24, ratings: MultiSourceRatings(tvMazeScore: 8.0)
        )
        let usAnim = MediaItem(
            id: "2", primarySource: .tvMaze, projectType: .cartoonSeries,
            localizedTitle: "US Toon", originalTitle: "US Toon", synopsis: "",
            releaseYear: 2023, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Animation"], durationMinutes: 22, ratings: MultiSourceRatings(tvMazeScore: 8.2)
        )

        let criteria = CatalogFilterCriteria(selectedCategory: .cartoonSeries)
        let filtered = CatalogQueryPlanner.postFilterAndSort(
            items: [jaAnim, usAnim],
            criteria: criteria,
            excludeJapaneseForCartoons: true
        )
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "2")
    }

    @Test func postFilterAcceptsDramaGenreItemsInsideDramaCategory() {
        let dramaSeries = MediaItem(
            id: "tvmaze:tv:10", primarySource: .tvMaze, projectType: .tvSeries,
            localizedTitle: "Prestige Series", originalTitle: "Prestige Series", synopsis: "",
            releaseYear: 2024, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama", "Crime"], durationMinutes: 55, ratings: MultiSourceRatings(tvMazeScore: 8.5)
        )
        let comedyMovie = MediaItem(
            id: "opencinema:movie:itunes-20", primarySource: .openCinema, projectType: .movie,
            localizedTitle: "Pure Comedy", originalTitle: "Pure Comedy", synopsis: "",
            releaseYear: 2024, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Comedy"], durationMinutes: 95, ratings: MultiSourceRatings(tmdbScore: 7.5)
        )

        let result = CatalogQueryPlanner.postFilterAndSort(
            items: [dramaSeries, comedyMovie],
            criteria: CatalogFilterCriteria(selectedCategory: .drama)
        )
        #expect(result.count == 1)
        #expect(result.first?.id == "tvmaze:tv:10")
    }

    @Test func postFilterEnforcesYearRangeRatingDurationStatusAndCountry() {
        let matching = MediaItem(
            id: "m1", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Match", originalTitle: "Match", synopsis: "",
            releaseYear: 2021, countryOfOrigin: "KR", originalLanguage: "ko",
            genres: ["Thriller"], durationMinutes: 118, releaseStatus: .finished,
            ratings: MultiSourceRatings(tmdbScore: 8.6)
        )
        let tooLong = MediaItem(
            id: "m2", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Long", originalTitle: "Long", synopsis: "",
            releaseYear: 2021, countryOfOrigin: "KR", originalLanguage: "ko",
            genres: ["Thriller"], durationMinutes: 185, releaseStatus: .finished,
            ratings: MultiSourceRatings(tmdbScore: 8.9)
        )

        var criteria = CatalogFilterCriteria()
        criteria.yearFrom = 2020
        criteria.yearTo = 2023
        criteria.country = "KR"
        criteria.language = "ko"
        criteria.minimumRating = 8.0
        criteria.maxDurationMinutes = 130
        criteria.releaseStatus = .finished
        criteria.selectedGenres = ["Thriller"]

        let res = CatalogQueryPlanner.postFilterAndSort(items: [matching, tooLong], criteria: criteria)
        #expect(res.map(\.id) == ["m1"])
    }

    @Test func sortsItemsByPopularityRatingTitleAndReleaseDate() {
        let alpha = MediaItem(
            id: "a", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Alpha", originalTitle: "Alpha", synopsis: "",
            releaseYear: 2019, countryOfOrigin: "US", originalLanguage: "en",
            genres: [], durationMinutes: 100, ratings: MultiSourceRatings(tmdbScore: 9.2), popularityScore: 120
        )
        let zeta = MediaItem(
            id: "z", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Zeta", originalTitle: "Zeta", synopsis: "",
            releaseYear: 2025, countryOfOrigin: "US", originalLanguage: "en",
            genres: [], durationMinutes: 100, ratings: MultiSourceRatings(tmdbScore: 7.4), popularityScore: 950
        )

        #expect(CatalogQueryPlanner.sortItems([alpha, zeta], by: .popularity).map(\.id) == ["z", "a"])
        #expect(CatalogQueryPlanner.sortItems([zeta, alpha], by: .rating).map(\.id) == ["a", "z"])
        #expect(CatalogQueryPlanner.sortItems([zeta, alpha], by: .title).map(\.id) == ["a", "z"])
        #expect(CatalogQueryPlanner.sortItems([alpha, zeta], by: .releaseDate).map(\.id) == ["z", "a"])
    }

    @Test func filterCriteriaCountsActiveFiltersAndResetsCleanly() {
        var criteria = CatalogFilterCriteria(selectedCategory: .movie)
        criteria.selectedGenres = ["Sci-Fi", "Action"]
        criteria.minimumRating = 7.5
        criteria.yearFrom = 2015
        #expect(criteria.activeFilterCount > 0)

        criteria.reset()
        #expect(criteria.selectedGenres.isEmpty)
        #expect(criteria.minimumRating == 0)
        #expect(criteria.yearFrom == nil)
    }
}
