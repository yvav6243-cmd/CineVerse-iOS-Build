import Foundation

public struct CineVerseBackup: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let entries: [LibraryEntryDTO]
    public let progress: [PlaybackProgressDTO]
    public let history: [WatchHistoryDTO]
    public let collections: [CollectionDTO]
    public let sources: [UserVideoSourceDTO]
    public let preferences: AppPreferencesDTO?
    public let searchHistory: [SearchHistoryDTO]

    public init(
        schemaVersion: Int = CineVerseBackup.currentSchemaVersion,
        exportedAt: Date = Date(),
        entries: [LibraryEntryDTO],
        progress: [PlaybackProgressDTO],
        history: [WatchHistoryDTO],
        collections: [CollectionDTO],
        sources: [UserVideoSourceDTO],
        preferences: AppPreferencesDTO?,
        searchHistory: [SearchHistoryDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.progress = progress
        self.history = history
        self.collections = collections
        self.sources = sources
        self.preferences = preferences
        self.searchHistory = searchHistory
    }
}

public struct LibraryEntryDTO: Codable, Sendable {
    public let mediaID: String
    public let title: String
    public let originalTitle: String
    public let projectTypeRaw: String
    public let posterURLString: String?
    public let backdropURLString: String?
    public let genres: [String]
    public let releaseYear: Int
    public let statusRaw: String?
    public let isFavorite: Bool
    public let inWatchlist: Bool
    public let personalRating: Double?
    public let notes: String
    public let startDate: Date?
    public let finishDate: Date?
    public let addedAt: Date
    public let updatedAt: Date
    public let totalEpisodes: Int
    public let totalSeasons: Int
    public let episodeDurationMinutes: Int
    public let rewatchCount: Int
    public let alertsEnabled: Bool
    public let preferredSourceID: String?
    public let preferredAudioLanguage: String?
    public let preferredSubtitleLanguage: String?
    public let preferredQualityRaw: String?
}

public struct PlaybackProgressDTO: Codable, Sendable {
    public let key: String
    public let mediaID: String
    public let season: Int
    public let episode: Int
    public let episodeTitle: String
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let isWatched: Bool
    public let watchedAt: Date?
    public let lastUpdated: Date
    public let sourceID: String?
}

public struct WatchHistoryDTO: Codable, Sendable {
    public let id: UUID
    public let mediaID: String
    public let title: String
    public let projectTypeRaw: String
    public let genres: [String]
    public let season: Int?
    public let episode: Int?
    public let minutesWatched: Int
    public let watchedAt: Date
}

public struct CollectionItemDTO: Codable, Sendable {
    public let mediaID: String
    public let title: String
    public let posterURLString: String?
    public let projectTypeRaw: String
    public let releaseYear: Int
    public let rating: Double
    public let addedAt: Date
    public let position: Int
}

public struct CollectionDTO: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let symbolName: String
    public let createdAt: Date
    public let sortOrder: Int
    public let items: [CollectionItemDTO]
}

public struct StoredSubtitleDTO: Codable, Hashable, Sendable {
    public let id: String
    public let languageCode: String
    public let displayName: String
    public let relativePathOrURL: String
    public let formatRaw: String

    public init(
        id: String = UUID().uuidString,
        languageCode: String,
        displayName: String,
        relativePathOrURL: String,
        formatRaw: String
    ) {
        self.id = id
        self.languageCode = languageCode
        self.displayName = displayName
        self.relativePathOrURL = relativePathOrURL
        self.formatRaw = formatRaw
    }
}

public struct UserVideoSourceDTO: Codable, Sendable {
    public let id: UUID
    public let mediaID: String
    public let season: Int?
    public let episode: Int?
    public let kindRaw: String
    public let urlString: String?
    public let label: String
    public let isRestorable: Bool
    public let subtitles: [StoredSubtitleDTO]
    public let addedAt: Date
}

public struct AppPreferencesDTO: Codable, Sendable {
    public let profileName: String
    public let themeRaw: String
    public let contentLanguageCode: String
    public let defaultAudioLanguage: String
    public let defaultSubtitleLanguage: String
    public let defaultQualityRaw: String
    public let autoplayNext: Bool
    public let autosaveProgress: Bool
    public let episodeAlertsEnabled: Bool
    public let homeSections: [HomeSectionConfiguration]
    public let subtitleStyle: SubtitleAppearanceStyle
    public let watchRegion: String
}

public struct SearchHistoryDTO: Codable, Sendable {
    public let query: String
    public let searchedAt: Date
}

public enum BackupImportMode: String, CaseIterable, Identifiable, Sendable {
    case merge = "Merge with Existing"
    case replace = "Replace Library"

    public var id: String { rawValue }
}

public struct BackupImportReport: Sendable {
    public let entriesImported: Int
    public let progressImported: Int
    public let historyImported: Int
    public let collectionsImported: Int
    public let directSourcesImported: Int
    public let skippedLocalFiles: [String]
}
