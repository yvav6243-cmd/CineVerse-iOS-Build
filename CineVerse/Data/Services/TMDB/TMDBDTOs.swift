import Foundation

public struct TMDBPagedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let page: Int
    public let results: [T]
    public let totalPages: Int?
    public let totalResults: Int?

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

public struct TMDBGenreDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
}

public struct TMDBGenreListDTO: Decodable, Sendable {
    public let genres: [TMDBGenreDTO]
}

public struct TMDBCountryDTO: Decodable, Sendable {
    public let iso31661: String
    public let name: String

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case name
    }
}

public struct TMDBMovieSummaryDTO: Decodable, Sendable {
    public let id: Int
    public let title: String?
    public let originalTitle: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let genreIds: [Int]?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?
    public let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, popularity, adult
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case genreIds = "genre_ids"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
    }
}

public struct TMDBTVSummaryDTO: Decodable, Sendable {
    public let id: Int
    public let name: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let firstAirDate: String?
    public let genreIds: [Int]?
    public let originCountry: [String]?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case originCountry = "origin_country"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
    }
}

public struct TMDBMultiSearchDTO: Decodable, Sendable {
    public let id: Int
    public let mediaType: String?
    public let title: String?
    public let name: String?
    public let originalTitle: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let genreIds: [Int]?
    public let originCountry: [String]?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?
    public let knownForDepartment: String?
    public let knownFor: [TMDBMultiKnownForDTO]?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case mediaType = "media_type"
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case originCountry = "origin_country"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case knownForDepartment = "known_for_department"
        case knownFor = "known_for"
    }
}

public struct TMDBMultiKnownForDTO: Decodable, Sendable {
    public let id: Int
    public let mediaType: String?
    public let title: String?
    public let name: String?
    public let originalTitle: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let genreIds: [Int]?
    public let originCountry: [String]?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case mediaType = "media_type"
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case originCountry = "origin_country"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
    }
}

public struct TMDBCompanyDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
}

public struct TMDBCreditsDTO: Decodable, Sendable {
    public let cast: [TMDBCastMemberDTO]?
    public let crew: [TMDBCrewMemberDTO]?
}

public struct TMDBCastMemberDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let character: String?
    public let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

public struct TMDBCrewMemberDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let job: String?
    public let department: String?
    public let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}

public struct TMDBVideoListDTO: Decodable, Sendable {
    public let results: [TMDBVideoDTO]
}

public struct TMDBVideoDTO: Decodable, Sendable {
    public let id: String
    public let key: String
    public let name: String
    public let site: String
    public let type: String
    public let official: Bool?
}

public struct TMDBExternalIDsDTO: Decodable, Sendable {
    public let imdbId: String?
    public let tvdbId: Int?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case tvdbId = "tvdb_id"
    }
}

public struct TMDBReleaseDatesContainerDTO: Decodable, Sendable {
    public let results: [TMDBReleaseDateCountryDTO]?
}

public struct TMDBReleaseDateCountryDTO: Decodable, Sendable {
    public let iso31661: String
    public let releaseDates: [TMDBReleaseDateEntryDTO]?

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

public struct TMDBReleaseDateEntryDTO: Decodable, Sendable {
    public let certification: String?
}

public struct TMDBContentRatingsContainerDTO: Decodable, Sendable {
    public let results: [TMDBContentRatingDTO]?
}

public struct TMDBContentRatingDTO: Decodable, Sendable {
    public let iso31661: String
    public let rating: String

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case rating
    }
}

public struct TMDBWatchProvidersContainerDTO: Decodable, Sendable {
    public let results: [String: TMDBRegionProvidersDTO]?
}

public struct TMDBRegionProvidersDTO: Decodable, Sendable {
    public let link: String?
    public let flatrate: [TMDBWatchProviderItemDTO]?
    public let free: [TMDBWatchProviderItemDTO]?
    public let rent: [TMDBWatchProviderItemDTO]?
    public let buy: [TMDBWatchProviderItemDTO]?
}

public struct TMDBWatchProviderItemDTO: Decodable, Sendable {
    public let providerId: Int
    public let providerName: String

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
    }
}

public struct TMDBSeasonSummaryDTO: Decodable, Sendable {
    public let id: Int
    public let seasonNumber: Int
    public let name: String?
    public let overview: String?
    public let episodeCount: Int?
    public let posterPath: String?
    public let airDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
    }
}

public struct TMDBCreatorDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
}

public struct TMDBEpisodeDTO: Decodable, Sendable {
    public let id: Int
    public let seasonNumber: Int?
    public let episodeNumber: Int
    public let name: String?
    public let overview: String?
    public let runtime: Int?
    public let airDate: String?
    public let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}

public struct TMDBSeasonDetailsDTO: Decodable, Sendable {
    public let id: Int?
    public let seasonNumber: Int
    public let name: String?
    public let overview: String?
    public let posterPath: String?
    public let airDate: String?
    public let episodes: [TMDBEpisodeDTO]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
        case airDate = "air_date"
    }
}

public struct TMDBMovieDetailsDTO: Decodable, Sendable {
    public let id: Int
    public let title: String?
    public let originalTitle: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let genres: [TMDBGenreDTO]?
    public let runtime: Int?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let originalLanguage: String?
    public let originCountry: [String]?
    public let productionCountries: [TMDBCountryDTO]?
    public let productionCompanies: [TMDBCompanyDTO]?
    public let status: String?
    public let credits: TMDBCreditsDTO?
    public let videos: TMDBVideoListDTO?
    public let similar: TMDBPagedResponse<TMDBMovieSummaryDTO>?
    public let recommendations: TMDBPagedResponse<TMDBMovieSummaryDTO>?
    public let releaseDates: TMDBReleaseDatesContainerDTO?
    public let watchProviders: TMDBWatchProvidersContainerDTO?
    public let externalIds: TMDBExternalIDsDTO?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, genres, runtime, popularity, status, credits, videos, similar, recommendations
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case originalLanguage = "original_language"
        case originCountry = "origin_country"
        case productionCountries = "production_countries"
        case productionCompanies = "production_companies"
        case releaseDates = "release_dates"
        case watchProviders = "watch/providers"
        case externalIds = "external_ids"
    }
}

public struct TMDBTVDetailsDTO: Decodable, Sendable {
    public let id: Int
    public let name: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let firstAirDate: String?
    public let genres: [TMDBGenreDTO]?
    public let episodeRunTime: [Int]?
    public let numberOfSeasons: Int?
    public let numberOfEpisodes: Int?
    public let seasons: [TMDBSeasonSummaryDTO]?
    public let createdBy: [TMDBCreatorDTO]?
    public let originCountry: [String]?
    public let originalLanguage: String?
    public let status: String?
    public let type: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let popularity: Double?
    public let credits: TMDBCreditsDTO?
    public let videos: TMDBVideoListDTO?
    public let similar: TMDBPagedResponse<TMDBTVSummaryDTO>?
    public let recommendations: TMDBPagedResponse<TMDBTVSummaryDTO>?
    public let contentRatings: TMDBContentRatingsContainerDTO?
    public let watchProviders: TMDBWatchProvidersContainerDTO?
    public let externalIds: TMDBExternalIDsDTO?
    public let nextEpisodeToAir: TMDBEpisodeDTO?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, status, type, popularity, credits, videos, similar, recommendations, seasons
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case episodeRunTime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case createdBy = "created_by"
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case contentRatings = "content_ratings"
        case watchProviders = "watch/providers"
        case externalIds = "external_ids"
        case nextEpisodeToAir = "next_episode_to_air"
    }
}

public struct TMDBConfigurationDTO: Decodable, Sendable {
    public let changeKeys: [String]?

    enum CodingKeys: String, CodingKey {
        case changeKeys = "change_keys"
    }
}
