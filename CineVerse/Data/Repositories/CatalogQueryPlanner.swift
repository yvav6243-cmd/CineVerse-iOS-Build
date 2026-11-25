import Foundation

public enum CatalogPlannedRequest: Sendable {
    case tmdbMovies(TMDBDiscoverParameters, excludeJapanese: Bool)
    case tmdbTV(TMDBDiscoverParameters, excludeJapanese: Bool)
    case aniList(AniListSearchParameters)
    case tvMazeIndex(page: Int)
    case iTunesCategory(MediaProjectType, page: Int)
    case internetArchive(MediaProjectType?, page: Int)
    case peerTubeOpen(MediaProjectType?, page: Int)
}

public enum CatalogQueryPlanner {
    public static func planRequests(
        criteria: CatalogFilterCriteria,
        page: Int,
        language: String,
        hasTMDBCredential: Bool
    ) -> [CatalogPlannedRequest] {
        switch criteria.selectedCategory {
        case .movie:
            return hasTMDBCredential
                ? [
                    .tmdbMovies(makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: [16, 99]), excludeJapanese: false),
                    .internetArchive(.movie, page: page)
                ]
                : [
                    .iTunesCategory(.movie, page: page),
                    .internetArchive(.movie, page: page)
                ]

        case .anime:
            return [.aniList(makeAniListParams(criteria: criteria, page: page, formats: ["TV", "TV_SHORT", "ONA"]))]

        case .animeMovie:
            var requests: [CatalogPlannedRequest] = [
                .aniList(makeAniListParams(criteria: criteria, page: page, formats: ["MOVIE"]))
            ]
            if hasTMDBCredential {
                var p = makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [16], withoutGenres: [])
                p.originalLanguage = "ja"
                requests.append(.tmdbMovies(p, excludeJapanese: false))
            } else if page == 1 {
                requests.append(.iTunesCategory(.animeMovie, page: page))
            }
            return requests

        case .tvSeries:
            if hasTMDBCredential {
                return [.tmdbTV(makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: [16, 99]), excludeJapanese: false)]
            } else {
                return [.tvMazeIndex(page: page)]
            }

        case .cartoonSeries:
            guard hasTMDBCredential else {
                return [.tvMazeIndex(page: page * 2 - 1), .tvMazeIndex(page: page * 2)]
            }
            return [.tmdbTV(makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [16], withoutGenres: []), excludeJapanese: true)]

        case .cartoonMovie:
            guard hasTMDBCredential else {
                return [
                    .iTunesCategory(.cartoonMovie, page: page),
                    .internetArchive(.cartoonMovie, page: page)
                ]
            }
            return [.tmdbMovies(makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [16], withoutGenres: []), excludeJapanese: true)]

        case .drama:
            guard hasTMDBCredential else {
                return [
                    .iTunesCategory(.drama, page: page),
                    .tvMazeIndex(page: page)
                ]
            }
            var p = makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [18], withoutGenres: [16])
            if p.originCountry == nil {
                p.originCountry = "KR|CN|TW|TH|JP"
            }
            return [.tmdbTV(p, excludeJapanese: false)]

        case .documentary:
            guard hasTMDBCredential else {
                return [
                    .iTunesCategory(.documentary, page: page),
                    .tvMazeIndex(page: page * 2 - 1),
                    .tvMazeIndex(page: page * 2),
                    .internetArchive(.documentary, page: page)
                ]
            }
            return [
                .tmdbMovies(makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [99], withoutGenres: []), excludeJapanese: false),
                .tmdbTV(makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [99], withoutGenres: []), excludeJapanese: false),
                .internetArchive(.documentary, page: page)
            ]

        case .shortFilm:
            var requests: [CatalogPlannedRequest] = [
                .internetArchive(.shortFilm, page: page),
                .peerTubeOpen(.shortFilm, page: page)
            ]
            if hasTMDBCredential {
                var p = makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: [])
                p.maxDurationMinutes = criteria.maxDurationMinutes ?? 45
                requests.insert(.tmdbMovies(p, excludeJapanese: false), at: 0)
            }
            return requests

        case .indieFestival:
            var requests: [CatalogPlannedRequest] = [
                .internetArchive(.indieFestival, page: page),
                .peerTubeOpen(.indieFestival, page: page),
                .iTunesCategory(.indieFestival, page: page)
            ]
            if hasTMDBCredential {
                let p = makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: [])
                requests.insert(.tmdbMovies(p, excludeJapanese: false), at: 0)
            }
            return requests

        case .special:
            var requests: [CatalogPlannedRequest] = [
                .aniList(makeAniListParams(criteria: criteria, page: page, formats: ["OVA", "SPECIAL", "MUSIC"]))
            ]
            if page == 1 {
                requests.append(.iTunesCategory(.special, page: 1))
            }
            return requests

        case .other:
            guard hasTMDBCredential else {
                return [.tvMazeIndex(page: page * 2 - 1), .tvMazeIndex(page: page * 2)]
            }
            var p = makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: [])
            p.tvTypeCode = "3|5|6"
            return [.tmdbTV(p, excludeJapanese: false)]

        case nil:
            var requests: [CatalogPlannedRequest] = []
            if hasTMDBCredential {
                requests.append(.tmdbMovies(makeTMDBMovieParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: []), excludeJapanese: false))
                requests.append(.tmdbTV(makeTMDBTVParams(criteria: criteria, page: page, language: language, withGenres: [], withoutGenres: []), excludeJapanese: false))
            } else {
                requests.append(.iTunesCategory(.movie, page: page))
                requests.append(.tvMazeIndex(page: page))
            }
            requests.append(.aniList(makeAniListParams(criteria: criteria, page: page, formats: nil)))
            requests.append(.internetArchive(nil, page: page))
            return requests
        }
    }

    public static func postFilterAndSort(
        items: [MediaItem],
        criteria: CatalogFilterCriteria,
        query: String? = nil,
        excludeJapaneseForCartoons: Bool = false,
        userPlayableMediaIDs: Set<String> = []
    ) -> [MediaItem] {
        let filtered = items.filter { item in
            if let category = criteria.selectedCategory {
                if category == .drama {
                    let hasDramaGenre = item.genres.contains { $0.localizedCaseInsensitiveContains("drama") }
                    if item.projectType != .drama && !hasDramaGenre {
                        return false
                    }
                } else if category == .special {
                    if item.projectType != .special && item.primarySource != .openCinema {
                        return false
                    }
                } else if category == .shortFilm {
                    let isShortRuntime = item.durationMinutes > 0 && item.durationMinutes <= 45 && !item.projectType.isEpisodic
                    if item.projectType != .shortFilm && !isShortRuntime {
                        return false
                    }
                } else if category == .indieFestival {
                    let isIndie = item.projectType == .indieFestival
                        || item.primarySource == .internetArchive
                        || item.genres.contains { $0.localizedCaseInsensitiveContains("independent") || $0.localizedCaseInsensitiveContains("indie") }
                    if !isIndie {
                        return false
                    }
                } else if item.projectType != category {
                    return false
                }
            }
            if excludeJapaneseForCartoons && item.originalLanguage.lowercased() == "ja" {
                return false
            }
            if !criteria.selectedGenres.isEmpty {
                let itemGenres = Set(item.genres.map { $0.lowercased() })
                let required = criteria.selectedGenres.map { $0.lowercased() }
                if !required.contains(where: { itemGenres.contains($0) }) {
                    return false
                }
            }
            if let from = criteria.yearFrom, item.releaseYear > 0, item.releaseYear < from {
                return false
            }
            if let to = criteria.yearTo, item.releaseYear > 0, item.releaseYear > to {
                return false
            }
            if let country = criteria.country?.nilIfEmpty,
               item.countryOfOrigin.lowercased() != country.lowercased() {
                return false
            }
            if let lang = criteria.language?.nilIfEmpty,
               item.originalLanguage.lowercased() != lang.lowercased() {
                return false
            }
            if criteria.minimumRating > 0 && item.displayRating < criteria.minimumRating {
                return false
            }
            if let status = criteria.releaseStatus, item.releaseStatus != status {
                return false
            }
            if let maxDuration = criteria.maxDurationMinutes,
               item.durationMinutes > 0,
               item.durationMinutes > maxDuration {
                return false
            }
            if let minSeasons = criteria.minSeasonsCount,
               item.totalSeasons < minSeasons {
                return false
            }
            if criteria.searchByOriginalTitleOnly, let q = query?.nilIfEmpty {
                let foldedQuery = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let candidates = [item.originalTitle] + item.alternativeTitles
                let matchesOrigOrAlt = candidates.contains {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(foldedQuery)
                }
                if !matchesOrigOrAlt {
                    return false
                }
            }
            if !PlayableCatalogEvaluator.matchesAdvancedCriteria(
                item: item,
                criteria: criteria,
                userPlayableMediaIDs: userPlayableMediaIDs
            ) {
                return false
            }
            return true
        }

        return sortItems(filtered, by: criteria.sortBy)
    }

    public static func sortItems(_ items: [MediaItem], by sort: CatalogSortOption) -> [MediaItem] {
        switch sort {
        case .popularity:
            return items.sorted { $0.popularityScore > $1.popularityScore }
        case .rating:
            return items.sorted { $0.displayRating > $1.displayRating }
        case .releaseDate, .recentlyAdded:
            return items.sorted {
                let d0 = $0.releaseDate ?? Date.distantPast
                let d1 = $1.releaseDate ?? Date.distantPast
                if d0 != d1 { return d0 > d1 }
                return $0.releaseYear > $1.releaseYear
            }
        case .title:
            return items.sorted {
                $0.localizedTitle.localizedCaseInsensitiveCompare($1.localizedTitle) == .orderedAscending
            }
        }
    }

    private static func makeTMDBMovieParams(
        criteria: CatalogFilterCriteria,
        page: Int,
        language: String,
        withGenres: [Int],
        withoutGenres: [Int]
    ) -> TMDBDiscoverParameters {
        var params = TMDBDiscoverParameters()
        params.page = page
        params.language = language
        params.withGenres = withGenres + criteria.selectedGenres.compactMap(TMDBMapper.genreID(for:))
        params.withoutGenres = withoutGenres
        params.yearFrom = criteria.yearFrom
        params.yearTo = criteria.yearTo
        params.originCountry = criteria.country
        params.originalLanguage = criteria.language
        params.minRating = criteria.minimumRating > 0 ? criteria.minimumRating : nil
        params.maxRating = criteria.maximumRating < 10.0 ? criteria.maximumRating : nil
        params.maxDurationMinutes = criteria.maxDurationMinutes
        params.sortBy = tmdbSortKey(for: criteria.sortBy, isMovie: true)
        return params
    }

    private static func makeTMDBTVParams(
        criteria: CatalogFilterCriteria,
        page: Int,
        language: String,
        withGenres: [Int],
        withoutGenres: [Int]
    ) -> TMDBDiscoverParameters {
        var params = TMDBDiscoverParameters()
        params.page = page
        params.language = language
        params.withGenres = withGenres + criteria.selectedGenres.compactMap(TMDBMapper.genreID(for:))
        params.withoutGenres = withoutGenres
        params.yearFrom = criteria.yearFrom
        params.yearTo = criteria.yearTo
        params.originCountry = criteria.country
        params.originalLanguage = criteria.language
        params.minRating = criteria.minimumRating > 0 ? criteria.minimumRating : nil
        params.maxRating = criteria.maximumRating < 10.0 ? criteria.maximumRating : nil
        params.maxDurationMinutes = criteria.maxDurationMinutes
        params.tvStatusCode = criteria.releaseStatus.flatMap(tmdbTVStatusCode(for:))
        params.sortBy = tmdbSortKey(for: criteria.sortBy, isMovie: false)
        return params
    }

    private static func makeAniListParams(
        criteria: CatalogFilterCriteria,
        page: Int,
        formats: [String]?
    ) -> AniListSearchParameters {
        var params = AniListSearchParameters()
        params.page = page
        params.perPage = 30
        params.formats = formats
        params.genres = criteria.selectedGenres.isEmpty ? nil : Array(criteria.selectedGenres)
        params.yearFrom = criteria.yearFrom
        params.yearTo = criteria.yearTo
        params.countryOfOrigin = criteria.country
        params.minRating = criteria.minimumRating > 0 ? criteria.minimumRating : nil
        params.maxRating = criteria.maximumRating < 10.0 ? criteria.maximumRating : nil
        params.maxDurationMinutes = criteria.maxDurationMinutes
        params.status = criteria.releaseStatus.flatMap(aniListStatus(for:))
        params.sort = aniListSort(for: criteria.sortBy)
        return params
    }

    private static func tmdbSortKey(for sort: CatalogSortOption, isMovie: Bool) -> String {
        switch sort {
        case .popularity: return "popularity.desc"
        case .rating: return "vote_average.desc"
        case .releaseDate, .recentlyAdded:
            return isMovie ? "primary_release_date.desc" : "first_air_date.desc"
        case .title:
            return isMovie ? "title.asc" : "name.asc"
        }
    }

    private static func tmdbTVStatusCode(for status: MediaReleaseStatus) -> String? {
        switch status {
        case .releasing: return "0"
        case .upcoming: return "1|2"
        case .finished: return "3"
        case .cancelled: return "4"
        case .hiatus: return nil
        }
    }

    private static func aniListStatus(for status: MediaReleaseStatus) -> String? {
        switch status {
        case .releasing: return "RELEASING"
        case .finished: return "FINISHED"
        case .upcoming: return "NOT_YET_RELEASED"
        case .hiatus: return "HIATUS"
        case .cancelled: return "CANCELLED"
        }
    }

    private static func aniListSort(for sort: CatalogSortOption) -> [String] {
        switch sort {
        case .popularity: return ["POPULARITY_DESC"]
        case .rating: return ["SCORE_DESC"]
        case .releaseDate, .recentlyAdded: return ["START_DATE_DESC"]
        case .title: return ["TITLE_ROMAJI"]
        }
    }
}
