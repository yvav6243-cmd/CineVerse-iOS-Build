import Foundation

public enum TMDBMapper {
    public static func mapMovieSummary(_ dto: TMDBMovieSummaryDTO) -> MediaItem {
        let genreIDs = dto.genreIds ?? []
        let genres = genreIDs.compactMap { genreNamesByID[$0] }
        let lang = (dto.originalLanguage ?? "en").lowercased()
        let projectType = classifyMovie(genreIDs: genreIDs, originalLanguage: lang)
        let releaseDate = dto.releaseDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        let year = extractYear(from: dto.releaseDate, date: releaseDate)
        let status: MediaReleaseStatus = (releaseDate ?? .distantPast) > Date() ? .upcoming : .finished
        let ref = MediaReference(provider: .tmdb, kind: .movie, providerID: String(dto.id))

        return MediaItem(
            id: ref.id,
            externalIDs: [.tmdb: String(dto.id)],
            primarySource: .tmdb,
            projectType: projectType,
            localizedTitle: dto.title?.nilIfEmpty ?? dto.originalTitle ?? "Untitled",
            originalTitle: dto.originalTitle?.nilIfEmpty ?? dto.title ?? "Untitled",
            synopsis: dto.overview?.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: lang == "ja" ? "JP" : (lang == "ko" ? "KR" : "US"),
            originalLanguage: lang,
            ageRating: dto.adult == true ? "18+" : "13+",
            genres: genres,
            durationMinutes: 0,
            totalSeasons: 1,
            totalEpisodes: 1,
            releaseStatus: status,
            ratings: MultiSourceRatings(tmdbScore: dto.voteAverage, voteCount: dto.voteCount),
            popularityScore: dto.popularity ?? 0,
            posterURL: imageURL(path: dto.posterPath, size: "w500"),
            backdropURL: imageURL(path: dto.backdropPath, size: "w1280")
        )
    }

    public static func mapTVSummary(_ dto: TMDBTVSummaryDTO) -> MediaItem {
        let genreIDs = dto.genreIds ?? []
        let genres = genreIDs.compactMap { genreNamesByID[$0] }
        let lang = (dto.originalLanguage ?? "en").lowercased()
        let origins = dto.originCountry ?? []
        let projectType = classifyTV(genreIDs: genreIDs, originalLanguage: lang, origins: origins, tmdbType: nil)
        let releaseDate = dto.firstAirDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        let year = extractYear(from: dto.firstAirDate, date: releaseDate)
        let ref = MediaReference(provider: .tmdb, kind: .tv, providerID: String(dto.id))

        return MediaItem(
            id: ref.id,
            externalIDs: [.tmdb: String(dto.id)],
            primarySource: .tmdb,
            projectType: projectType,
            localizedTitle: dto.name?.nilIfEmpty ?? dto.originalName ?? "Untitled",
            originalTitle: dto.originalName?.nilIfEmpty ?? dto.name ?? "Untitled",
            synopsis: dto.overview?.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: origins.first ?? (lang == "ja" ? "JP" : "US"),
            originalLanguage: lang,
            ageRating: "16+",
            genres: genres,
            durationMinutes: 45,
            totalSeasons: 1,
            totalEpisodes: 1,
            releaseStatus: (releaseDate ?? .distantPast) > Date() ? .upcoming : .releasing,
            ratings: MultiSourceRatings(tmdbScore: dto.voteAverage, voteCount: dto.voteCount),
            popularityScore: dto.popularity ?? 0,
            posterURL: imageURL(path: dto.posterPath, size: "w500"),
            backdropURL: imageURL(path: dto.backdropPath, size: "w1280")
        )
    }

    public static func mapMultiSearch(_ dto: TMDBMultiSearchDTO) -> MediaItem? {
        mapMultiSearchItems(dto).first
    }

    public static func mapMultiSearchItems(_ dto: TMDBMultiSearchDTO) -> [MediaItem] {
        guard let mediaType = dto.mediaType else { return [] }
        if mediaType == "movie" {
            let movie = TMDBMovieSummaryDTO(
                id: dto.id, title: dto.title, originalTitle: dto.originalTitle, overview: dto.overview,
                posterPath: dto.posterPath, backdropPath: dto.backdropPath, releaseDate: dto.releaseDate,
                genreIds: dto.genreIds, voteAverage: dto.voteAverage, voteCount: dto.voteCount,
                popularity: dto.popularity, originalLanguage: dto.originalLanguage, adult: false
            )
            return [mapMovieSummary(movie)]
        } else if mediaType == "tv" {
            let tv = TMDBTVSummaryDTO(
                id: dto.id, name: dto.name, originalName: dto.originalName, overview: dto.overview,
                posterPath: dto.posterPath, backdropPath: dto.backdropPath, firstAirDate: dto.firstAirDate,
                genreIds: dto.genreIds, originCountry: dto.originCountry, voteAverage: dto.voteAverage,
                voteCount: dto.voteCount, popularity: dto.popularity, originalLanguage: dto.originalLanguage
            )
            return [mapTVSummary(tv)]
        } else if mediaType == "person", let knownList = dto.knownFor {
            let personName = dto.name ?? ""
            let isDirecting = dto.knownForDepartment?.lowercased() == "directing"
            return knownList.compactMap { kf -> MediaItem? in
                if kf.mediaType == "movie" {
                    let movie = TMDBMovieSummaryDTO(
                        id: kf.id, title: kf.title, originalTitle: kf.originalTitle, overview: kf.overview,
                        posterPath: kf.posterPath, backdropPath: kf.backdropPath, releaseDate: kf.releaseDate,
                        genreIds: kf.genreIds, voteAverage: kf.voteAverage, voteCount: kf.voteCount,
                        popularity: kf.popularity, originalLanguage: kf.originalLanguage, adult: false
                    )
                    var item = mapMovieSummary(movie)
                    if !personName.isEmpty {
                        item.cast = [MediaCreditPerson(id: "tmdb:p:\(dto.id)", name: personName, roleOrCharacter: isDirecting ? "Director" : "Cast")]
                    }
                    return item
                } else if kf.mediaType == "tv" {
                    let tv = TMDBTVSummaryDTO(
                        id: kf.id, name: kf.name, originalName: kf.originalName, overview: kf.overview,
                        posterPath: kf.posterPath, backdropPath: kf.backdropPath, firstAirDate: kf.firstAirDate,
                        genreIds: kf.genreIds, originCountry: kf.originCountry, voteAverage: kf.voteAverage,
                        voteCount: kf.voteCount, popularity: kf.popularity, originalLanguage: kf.originalLanguage
                    )
                    var item = mapTVSummary(tv)
                    if !personName.isEmpty {
                        item.cast = [MediaCreditPerson(id: "tmdb:p:\(dto.id)", name: personName, roleOrCharacter: isDirecting ? "Creator" : "Cast")]
                    }
                    return item
                }
                return nil
            }
        }
        return []
    }

    public static func mapMovieDetails(_ dto: TMDBMovieDetailsDTO, watchRegion: String) -> MediaItem {
        let genreIDs = (dto.genres ?? []).map(\.id)
        let genres = (dto.genres ?? []).map(\.name)
        let lang = (dto.originalLanguage ?? "en").lowercased()
        let projectType = classifyMovie(genreIDs: genreIDs, originalLanguage: lang)
        let releaseDate = dto.releaseDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        let year = extractYear(from: dto.releaseDate, date: releaseDate)
        let ref = MediaReference(provider: .tmdb, kind: .movie, providerID: String(dto.id))

        let director = dto.credits?.crew?.first(where: { $0.job?.lowercased() == "director" })?.name ?? "Unknown Director"
        let cast = mapCast(dto.credits?.cast ?? [])
        let trailerURL = extractTrailerURL(from: dto.videos?.results ?? [])
        let certification = extractMovieCertification(dto.releaseDates, region: watchRegion) ?? "13+"
        let officialLinks = extractWatchProviderLinks(dto.watchProviders, region: watchRegion)

        var similarIDs: [String] = []
        let combinedRelated = (dto.recommendations?.results ?? []) + (dto.similar?.results ?? [])
        for rel in combinedRelated.prefix(12) {
            let relID = MediaReference(provider: .tmdb, kind: .movie, providerID: String(rel.id)).id
            if !similarIDs.contains(relID) {
                similarIDs.append(relID)
            }
        }

        let country = dto.originCountry?.first
            ?? dto.productionCountries?.first?.iso31661
            ?? "US"

        let status: MediaReleaseStatus
        if let releaseDate, releaseDate > Date() {
            status = .upcoming
        } else {
            status = mapMovieStatus(dto.status)
        }

        return MediaItem(
            id: ref.id,
            externalIDs: [.tmdb: String(dto.id)],
            primarySource: .tmdb,
            projectType: projectType,
            localizedTitle: dto.title?.nilIfEmpty ?? dto.originalTitle ?? "Untitled",
            originalTitle: dto.originalTitle?.nilIfEmpty ?? dto.title ?? "Untitled",
            synopsis: dto.overview?.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: country,
            originalLanguage: lang,
            ageRating: certification,
            genres: genres,
            durationMinutes: dto.runtime ?? 0,
            totalSeasons: 1,
            totalEpisodes: 1,
            releaseStatus: status,
            ratings: MultiSourceRatings(tmdbScore: dto.voteAverage, voteCount: dto.voteCount),
            popularityScore: dto.popularity ?? 0,
            posterURL: imageURL(path: dto.posterPath, size: "w500"),
            backdropURL: imageURL(path: dto.backdropPath, size: "w1280"),
            director: director,
            studio: dto.productionCompanies?.first?.name ?? "",
            cast: cast,
            seasons: [],
            trailerURL: trailerURL,
            officialPlatformLinks: officialLinks,
            similarProjectIDs: similarIDs
        )
    }

    public static func mapTVDetails(_ dto: TMDBTVDetailsDTO, watchRegion: String) -> MediaItem {
        let genreIDs = (dto.genres ?? []).map(\.id)
        let genres = (dto.genres ?? []).map(\.name)
        let lang = (dto.originalLanguage ?? "en").lowercased()
        let origins = dto.originCountry ?? []
        let projectType = classifyTV(genreIDs: genreIDs, originalLanguage: lang, origins: origins, tmdbType: dto.type)
        let releaseDate = dto.firstAirDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        let year = extractYear(from: dto.firstAirDate, date: releaseDate)
        let ref = MediaReference(provider: .tmdb, kind: .tv, providerID: String(dto.id))

        let creator = dto.createdBy?.first?.name
            ?? dto.credits?.crew?.first(where: { $0.job?.lowercased() == "executive producer" })?.name
            ?? "Series Creator"
        let cast = mapCast(dto.credits?.cast ?? [])
        let trailerURL = extractTrailerURL(from: dto.videos?.results ?? [])
        let rating = extractTVContentRating(dto.contentRatings, region: watchRegion) ?? "16+"
        let officialLinks = extractWatchProviderLinks(dto.watchProviders, region: watchRegion)

        var similarIDs: [String] = []
        let combinedRelated = (dto.recommendations?.results ?? []) + (dto.similar?.results ?? [])
        for rel in combinedRelated.prefix(12) {
            let relID = MediaReference(provider: .tmdb, kind: .tv, providerID: String(rel.id)).id
            if !similarIDs.contains(relID) {
                similarIDs.append(relID)
            }
        }

        let regularSeasons = (dto.seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }
            .map { season in
                MediaSeason(
                    id: "tmdb:tv:\(dto.id):s\(season.seasonNumber)",
                    seasonNumber: season.seasonNumber,
                    title: season.name?.nilIfEmpty ?? "Season \(season.seasonNumber)",
                    overview: season.overview ?? "",
                    episodeCount: season.episodeCount ?? 0,
                    posterURL: imageURL(path: season.posterPath, size: "w342"),
                    releaseYear: season.airDate.flatMap { Int($0.prefix(4)) },
                    episodes: []
                )
            }

        let specialsSeasons = (dto.seasons ?? [])
            .filter { $0.seasonNumber == 0 && ($0.episodeCount ?? 0) > 0 }
            .map { special in
                MediaSeason(
                    id: "tmdb:tv:\(dto.id):s0",
                    seasonNumber: 0,
                    title: "Specials & OVAs",
                    overview: special.overview ?? "",
                    episodeCount: special.episodeCount ?? 0,
                    posterURL: imageURL(path: special.posterPath, size: "w342"),
                    releaseYear: special.airDate.flatMap { Int($0.prefix(4)) },
                    episodes: []
                )
            }

        let seasons = regularSeasons + specialsSeasons

        let nextAirDate = dto.nextEpisodeToAir?.airDate.flatMap {
            CineVerseDateFormatters.isoDateParser.date(from: $0)
        }

        return MediaItem(
            id: ref.id,
            externalIDs: [.tmdb: String(dto.id)],
            primarySource: .tmdb,
            projectType: projectType,
            localizedTitle: dto.name?.nilIfEmpty ?? dto.originalName ?? "Untitled",
            originalTitle: dto.originalName?.nilIfEmpty ?? dto.name ?? "Untitled",
            synopsis: dto.overview?.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: origins.first ?? "US",
            originalLanguage: lang,
            ageRating: rating,
            genres: genres,
            durationMinutes: dto.episodeRunTime?.first ?? 45,
            totalSeasons: max(dto.numberOfSeasons ?? regularSeasons.count, 1),
            totalEpisodes: max(dto.numberOfEpisodes ?? 1, 1),
            releaseStatus: mapTVStatus(dto.status),
            ratings: MultiSourceRatings(tmdbScore: dto.voteAverage, voteCount: dto.voteCount),
            popularityScore: dto.popularity ?? 0,
            posterURL: imageURL(path: dto.posterPath, size: "w500"),
            backdropURL: imageURL(path: dto.backdropPath, size: "w1280"),
            director: creator,
            cast: cast,
            seasons: seasons,
            trailerURL: trailerURL,
            officialPlatformLinks: officialLinks,
            similarProjectIDs: similarIDs,
            nextAiringEpisodeNumber: dto.nextEpisodeToAir?.episodeNumber,
            nextAiringDate: nextAirDate
        )
    }

    public static func mapSeasonDetails(_ dto: TMDBSeasonDetailsDTO, tvID: String, defaultDuration: Int) -> MediaSeason {
        let episodes = (dto.episodes ?? []).map { ep in
            MediaEpisode(
                id: "tmdb:tv:\(tvID):s\(dto.seasonNumber):e\(ep.episodeNumber)",
                seasonNumber: ep.seasonNumber ?? dto.seasonNumber,
                episodeNumber: ep.episodeNumber,
                title: ep.name?.nilIfEmpty ?? "Episode \(ep.episodeNumber)",
                originalTitle: nil,
                synopsis: ep.overview?.nilIfEmpty ?? "No episode description available.",
                durationMinutes: ep.runtime ?? defaultDuration,
                airDate: ep.airDate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) },
                stillImageURL: imageURL(path: ep.stillPath, size: "w300")
            )
        }

        return MediaSeason(
            id: "tmdb:tv:\(tvID):s\(dto.seasonNumber)",
            seasonNumber: dto.seasonNumber,
            title: dto.name?.nilIfEmpty ?? "Season \(dto.seasonNumber)",
            overview: dto.overview ?? "",
            episodeCount: episodes.count,
            posterURL: imageURL(path: dto.posterPath, size: "w342"),
            releaseYear: dto.airDate.flatMap { Int($0.prefix(4)) },
            episodes: episodes
        )
    }
}
