import Foundation

// MARK: - Watch Tracking Status

public enum WatchTrackingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case planning = "Planning"
    case watching = "Watching"
    case completed = "Completed"
    case onHold = "On Hold"
    case dropped = "Dropped"
    case rewatching = "Rewatching"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .planning: return "calendar.badge.clock"
        case .watching: return "play.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .onHold: return "pause.circle.fill"
        case .dropped: return "xmark.circle.fill"
        case .rewatching: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    public var accentHex: String {
        switch self {
        case .planning: return "#5E5CE6"
        case .watching: return "#0A84FF"
        case .completed: return "#30D158"
        case .onHold: return "#FF9F0A"
        case .dropped: return "#FF453A"
        case .rewatching: return "#BF5AF2"
        }
    }
}

// MARK: - Home Screen Section Identifiers

public enum HomeSectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case continueWatching = "Continue Watching"
    case recentlyAdded = "Recently Added"
    case trendingMovies = "Trending Movies"
    case popularAnime = "Popular Anime"
    case popularTVShows = "Popular TV Shows"
    case upcomingReleases = "Upcoming Releases"
    case recommendedForYou = "Recommended For You"
    case topRated = "Top Rated"
    case recentlyWatched = "Recently Watched"
    case yourFavorites = "Your Favorites"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .continueWatching: return "Pick up right where you left off"
        case .recentlyAdded: return "Fresh arrivals across catalogs"
        case .trendingMovies: return "Most watched cinema right now"
        case .popularAnime: return "Top seasonal & all-time anime series"
        case .popularTVShows: return "Critically acclaimed television"
        case .upcomingReleases: return "Premieres arriving soon"
        case .recommendedForYou: return "Curated locally from your taste profile"
        case .topRated: return "Highest scored projects across platforms"
        case .recentlyWatched: return "Your recent viewing timeline"
        case .yourFavorites: return "Projects you loved most"
        }
    }

    public var symbolName: String {
        switch self {
        case .continueWatching: return "play.tv"
        case .recentlyAdded: return "sparkles.rectangle.stack"
        case .trendingMovies: return "flame.fill"
        case .popularAnime: return "sparkles.tv"
        case .popularTVShows: return "tv.fill"
        case .upcomingReleases: return "calendar.badge.plus"
        case .recommendedForYou: return "wand.and.stars"
        case .topRated: return "trophy.fill"
        case .recentlyWatched: return "clock.arrow.circlepath"
        case .yourFavorites: return "heart.fill"
        }
    }
}

public struct HomeSectionConfiguration: Codable, Identifiable, Hashable, Sendable {
    public var section: HomeSectionType
    public var isVisible: Bool
    public var sortOrder: Int

    public var id: String { section.rawValue }

    public init(section: HomeSectionType, isVisible: Bool = true, sortOrder: Int) {
        self.section = section
        self.isVisible = isVisible
        self.sortOrder = sortOrder
    }

    public static var defaultConfigurations: [HomeSectionConfiguration] {
        HomeSectionType.allCases.enumerated().map { index, type in
            HomeSectionConfiguration(section: type, isVisible: true, sortOrder: index)
        }
    }
}

// MARK: - Catalog Filtering & Sorting

public enum CatalogSortOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case popularity = "Popularity"
    case rating = "Rating"
    case releaseDate = "Release Date"
    case title = "Title"
    case recentlyAdded = "Recently Added"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .popularity: return "flame"
        case .rating: return "star"
        case .releaseDate: return "calendar"
        case .title: return "textformat.abc"
        case .recentlyAdded: return "clock"
        }
    }
}

public struct CatalogFilterCriteria: Codable, Hashable, Sendable {
    public var selectedCategory: MediaProjectType?
    public var selectedGenres: Set<String>
    public var yearFrom: Int?
    public var yearTo: Int?
    public var country: String?
    public var language: String?
    public var minimumRating: Double
    public var releaseStatus: MediaReleaseStatus?
    public var maxDurationMinutes: Int?
    public var minSeasonsCount: Int?
    public var sortBy: CatalogSortOption
    public var searchByOriginalTitleOnly: Bool

    public init(
        selectedCategory: MediaProjectType? = nil,
        selectedGenres: Set<String> = [],
        yearFrom: Int? = nil,
        yearTo: Int? = nil,
        country: String? = nil,
        language: String? = nil,
        minimumRating: Double = 0.0,
        releaseStatus: MediaReleaseStatus? = nil,
        maxDurationMinutes: Int? = nil,
        minSeasonsCount: Int? = nil,
        sortBy: CatalogSortOption = .popularity,
        searchByOriginalTitleOnly: Bool = false
    ) {
        self.selectedCategory = selectedCategory
        self.selectedGenres = selectedGenres
        self.yearFrom = yearFrom
        self.yearTo = yearTo
        self.country = country
        self.language = language
        self.minimumRating = minimumRating
        self.releaseStatus = releaseStatus
        self.maxDurationMinutes = maxDurationMinutes
        self.minSeasonsCount = minSeasonsCount
        self.sortBy = sortBy
        self.searchByOriginalTitleOnly = searchByOriginalTitleOnly
    }

    public var activeFilterCount: Int {
        var count = 0
        if selectedCategory != nil { count += 1 }
        if !selectedGenres.isEmpty { count += 1 }
        if yearFrom != nil || yearTo != nil { count += 1 }
        if country != nil { count += 1 }
        if language != nil { count += 1 }
        if minimumRating > 0 { count += 1 }
        if releaseStatus != nil { count += 1 }
        if maxDurationMinutes != nil { count += 1 }
        if minSeasonsCount != nil { count += 1 }
        if searchByOriginalTitleOnly { count += 1 }
        return count
    }

    public mutating func reset() {
        selectedCategory = nil
        selectedGenres.removeAll()
        yearFrom = nil
        yearTo = nil
        country = nil
        language = nil
        minimumRating = 0.0
        releaseStatus = nil
        maxDurationMinutes = nil
        minSeasonsCount = nil
        sortBy = .popularity
        searchByOriginalTitleOnly = false
    }
}

// MARK: - Tracker Statistics Summary

public struct MonthlyWatchActivityPoint: Identifiable, Hashable, Sendable {
    public let id: String
    public let monthLabel: String
    public let year: Int
    public let month: Int
    public let hoursWatched: Double
    public let episodesCount: Int

    public init(monthLabel: String, year: Int, month: Int, hoursWatched: Double, episodesCount: Int) {
        self.id = "\(year)-\(month)"
        self.monthLabel = monthLabel
        self.year = year
        self.month = month
        self.hoursWatched = hoursWatched
        self.episodesCount = episodesCount
    }
}

public struct GenreStatPoint: Identifiable, Hashable, Sendable {
    public let id: String
    public let genre: String
    public let projectCount: Int
    public let hoursWatched: Double
    public let averagePersonalRating: Double

    public init(genre: String, projectCount: Int, hoursWatched: Double, averagePersonalRating: Double) {
        self.id = genre
        self.genre = genre
        self.projectCount = projectCount
        self.hoursWatched = hoursWatched
        self.averagePersonalRating = averagePersonalRating
    }
}

public struct CategoryStatPoint: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: MediaProjectType
    public let count: Int
    public let hoursWatched: Double

    public init(category: MediaProjectType, count: Int, hoursWatched: Double) {
        self.id = category.rawValue
        self.category = category
        self.count = count
        self.hoursWatched = hoursWatched
    }
}

public struct TrackerAnalyticsSnapshot: Sendable {
    public let totalProjectsWatched: Int
    public let totalMoviesWatched: Int
    public let totalSeriesWatched: Int
    public let totalAnimeWatched: Int
    public let totalEpisodesWatched: Int
    public let totalSeasonsCompleted: Int
    public let totalHoursWatched: Double
    public let averagePersonalScore: Double
    public let statusBreakdown: [WatchTrackingStatus: Int]
    public let topGenres: [GenreStatPoint]
    public let monthlyActivity: [MonthlyWatchActivityPoint]
    public let categoryBreakdown: [CategoryStatPoint]

    public static let empty = TrackerAnalyticsSnapshot(
        totalProjectsWatched: 0,
        totalMoviesWatched: 0,
        totalSeriesWatched: 0,
        totalAnimeWatched: 0,
        totalEpisodesWatched: 0,
        totalSeasonsCompleted: 0,
        totalHoursWatched: 0,
        averagePersonalScore: 0,
        statusBreakdown: [:],
        topGenres: [],
        monthlyActivity: [],
        categoryBreakdown: []
    )
}
