import Foundation
import SwiftUI

// MARK: - Media Category & Project Type

public enum MediaProjectType: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie = "Movies"
    case anime = "Anime"
    case animeMovie = "Anime Movies"
    case tvSeries = "TV Series"
    case cartoonSeries = "Cartoon Series"
    case cartoonMovie = "Cartoons"
    case drama = "Dramas"
    case documentary = "Documentaries"
    case special = "Specials"
    case other = "Other Projects"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .anime: return "Anime"
        case .animeMovie: return "Anime Movie"
        case .tvSeries: return "TV Series"
        case .cartoonSeries: return "Animated Series"
        case .cartoonMovie: return "Animated Film"
        case .drama: return "Drama"
        case .documentary: return "Documentary"
        case .special: return "Special"
        case .other: return "Video Project"
        }
    }

    public var pluralTitle: String {
        switch self {
        case .movie: return "Movies"
        case .anime: return "Anime"
        case .animeMovie: return "Anime Movies"
        case .tvSeries: return "TV Series"
        case .cartoonSeries: return "Animated Series"
        case .cartoonMovie: return "Cartoons"
        case .drama: return "Dramas"
        case .documentary: return "Documentaries"
        case .special: return "Specials"
        case .other: return "Other Projects"
        }
    }

    public var symbolName: String {
        switch self {
        case .movie: return "film.stack"
        case .anime: return "sparkles.tv"
        case .animeMovie: return "film.circle"
        case .tvSeries: return "tv.inset.filled"
        case .cartoonSeries: return "paintbrush.pointed"
        case .cartoonMovie: return "theatermasks"
        case .drama: return "heart.text.square"
        case .documentary: return "globe.desk"
        case .special: return "star.square.on.square"
        case .other: return "play.rectangle.on.rectangle"
        }
    }

    public var isEpisodic: Bool {
        switch self {
        case .anime, .tvSeries, .cartoonSeries, .drama:
            return true
        case .movie, .animeMovie, .cartoonMovie, .documentary, .special, .other:
            return false
        }
    }
}

// MARK: - Release Status

public enum MediaReleaseStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case releasing = "Releasing"
    case finished = "Completed"
    case upcoming = "Upcoming"
    case hiatus = "On Hiatus"
    case cancelled = "Cancelled"

    public var id: String { rawValue }

    public var badgeColorHex: String {
        switch self {
        case .releasing: return "#34C759"
        case .finished: return "#0A84FF"
        case .upcoming: return "#FF9F0A"
        case .hiatus: return "#FFD60A"
        case .cancelled: return "#FF453A"
        }
    }
}

// MARK: - External Metadata Source

public enum MetadataProviderSource: String, Codable, CaseIterable, Sendable {
    case tmdb = "TMDB"
    case aniList = "AniList"
    case tvMaze = "TVmaze"
    case openCinema = "CineVerse Open Catalog"
}

// MARK: - Multi-Provider Rating Snapshot

public struct MultiSourceRatings: Codable, Hashable, Sendable {
    public var tmdbScore: Double?
    public var aniListScore: Double?
    public var tvMazeScore: Double?
    public var voteCount: Int?

    public init(
        tmdbScore: Double? = nil,
        aniListScore: Double? = nil,
        tvMazeScore: Double? = nil,
        voteCount: Int? = nil
    ) {
        self.tmdbScore = tmdbScore
        self.aniListScore = aniListScore
        self.tvMazeScore = tvMazeScore
        self.voteCount = voteCount
    }

    public var compositeScore: Double {
        let scores = [tmdbScore, aniListScore, tvMazeScore].compactMap { $0 }.filter { $0 > 0 }
        guard !scores.isEmpty else { return 0.0 }
        let sum = scores.reduce(0.0, +)
        return sum / Double(scores.count)
    }
}

// MARK: - Cast & Crew Member

public struct MediaCreditPerson: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let roleOrCharacter: String
    public let department: String
    public let profileImageURL: URL?

    public init(
        id: String,
        name: String,
        roleOrCharacter: String,
        department: String = "Acting",
        profileImageURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.roleOrCharacter = roleOrCharacter
        self.department = department
        self.profileImageURL = profileImageURL
    }
}

// MARK: - Episode & Season Models

public struct MediaEpisode: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let title: String
    public let originalTitle: String?
    public let synopsis: String
    public let durationMinutes: Int
    public let airDate: Date?
    public let stillImageURL: URL?
    public let directStreamURL: URL?

    public init(
        id: String,
        seasonNumber: Int,
        episodeNumber: Int,
        title: String,
        originalTitle: String? = nil,
        synopsis: String,
        durationMinutes: Int,
        airDate: Date? = nil,
        stillImageURL: URL? = nil,
        directStreamURL: URL? = nil
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.originalTitle = originalTitle
        self.synopsis = synopsis
        self.durationMinutes = durationMinutes
        self.airDate = airDate
        self.stillImageURL = stillImageURL
        self.directStreamURL = directStreamURL
    }

    public var formattedCode: String {
        String(format: "S%d E%d", seasonNumber, episodeNumber)
    }
}

public struct MediaSeason: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let seasonNumber: Int
    public let title: String
    public let overview: String
    public let episodeCount: Int
    public let posterURL: URL?
    public let releaseYear: Int?
    public var episodes: [MediaEpisode]

    public init(
        id: String,
        seasonNumber: Int,
        title: String,
        overview: String = "",
        episodeCount: Int,
        posterURL: URL? = nil,
        releaseYear: Int? = nil,
        episodes: [MediaEpisode] = []
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.title = title
        self.overview = overview
        self.episodeCount = episodeCount
        self.posterURL = posterURL
        self.releaseYear = releaseYear
        self.episodes = episodes
    }
}

// MARK: - Official Streaming Link

public struct ExternalOfficialPlatformLink: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let siteName: String
    public let url: URL
    public let languageCode: String?

    public init(id: String, siteName: String, url: URL, languageCode: String? = nil) {
        self.id = id
        self.siteName = siteName
        self.url = url
        self.languageCode = languageCode
    }
}

// MARK: - Primary Unified Media Item

public struct MediaItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let externalIDs: [MetadataProviderSource: String]
    public let primarySource: MetadataProviderSource
    public let projectType: MediaProjectType
    public let localizedTitle: String
    public let originalTitle: String
    public let synopsis: String
    public let releaseYear: Int
    public let releaseDate: Date?
    public let countryOfOrigin: String
    public let originalLanguage: String
    public let ageRating: String
    public let genres: [String]
    public let durationMinutes: Int
    public let totalSeasons: Int
    public let totalEpisodes: Int
    public let releaseStatus: MediaReleaseStatus
    public var ratings: MultiSourceRatings
    public let popularityScore: Double
    public let posterURL: URL?
    public let backdropURL: URL?
    public let bannerAccentHex: String?
    public let director: String
    public var cast: [MediaCreditPerson]
    public var seasons: [MediaSeason]
    public let trailerURL: URL?
    public var officialPlatformLinks: [ExternalOfficialPlatformLink]
    public var similarProjectIDs: [String]
    public let nextAiringEpisodeNumber: Int?
    public let nextAiringDate: Date?

    public init(
        id: String,
        externalIDs: [MetadataProviderSource: String] = [:],
        primarySource: MetadataProviderSource,
        projectType: MediaProjectType,
        localizedTitle: String,
        originalTitle: String,
        synopsis: String,
        releaseYear: Int,
        releaseDate: Date? = nil,
        countryOfOrigin: String,
        originalLanguage: String,
        ageRating: String = "16+",
        genres: [String],
        durationMinutes: Int,
        totalSeasons: Int = 1,
        totalEpisodes: Int = 1,
        releaseStatus: MediaReleaseStatus = .finished,
        ratings: MultiSourceRatings,
        popularityScore: Double = 100.0,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        bannerAccentHex: String? = nil,
        director: String = "Unknown Director",
        cast: [MediaCreditPerson] = [],
        seasons: [MediaSeason] = [],
        trailerURL: URL? = nil,
        officialPlatformLinks: [ExternalOfficialPlatformLink] = [],
        similarProjectIDs: [String] = [],
        nextAiringEpisodeNumber: Int? = nil,
        nextAiringDate: Date? = nil
    ) {
        self.id = id
        self.externalIDs = externalIDs
        self.primarySource = primarySource
        self.projectType = projectType
        self.localizedTitle = localizedTitle
        self.originalTitle = originalTitle
        self.synopsis = synopsis
        self.releaseYear = releaseYear
        self.releaseDate = releaseDate
        self.countryOfOrigin = countryOfOrigin
        self.originalLanguage = originalLanguage
        self.ageRating = ageRating
        self.genres = genres
        self.durationMinutes = durationMinutes
        self.totalSeasons = totalSeasons
        self.totalEpisodes = totalEpisodes
        self.releaseStatus = releaseStatus
        self.ratings = ratings
        self.popularityScore = popularityScore
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.bannerAccentHex = bannerAccentHex
        self.director = director
        self.cast = cast
        self.seasons = seasons
        self.trailerURL = trailerURL
        self.officialPlatformLinks = officialPlatformLinks
        self.similarProjectIDs = similarProjectIDs
        self.nextAiringEpisodeNumber = nextAiringEpisodeNumber
        self.nextAiringDate = nextAiringDate
    }

    public var displayRating: Double {
        ratings.compositeScore
    }

    public var formattedRating: String {
        let score = displayRating
        return score > 0 ? String(format: "%.1f", score) : "NR"
    }

    public var formattedDuration: String {
        if projectType.isEpisodic {
            if totalSeasons > 1 {
                return "\(totalSeasons) Seasons • \(totalEpisodes) Eps"
            } else {
                return "\(max(totalEpisodes, 1)) Episodes • ~\(max(durationMinutes, 24))m"
            }
        } else {
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            if hours > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(durationMinutes)m"
        }
    }
}
