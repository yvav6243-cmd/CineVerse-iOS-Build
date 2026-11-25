import Foundation
import SwiftData

@Model
public final class LibraryEntryRecord {
    @Attribute(.unique) public var mediaID: String
    public var title: String
    public var originalTitle: String
    public var projectTypeRaw: String
    public var posterURLString: String?
    public var backdropURLString: String?
    public var genres: [String]
    public var releaseYear: Int
    public var statusRaw: String?
    public var isFavorite: Bool
    public var inWatchlist: Bool
    public var personalRating: Double?
    public var notes: String
    public var startDate: Date?
    public var finishDate: Date?
    public var addedAt: Date
    public var updatedAt: Date
    public var totalEpisodes: Int
    public var totalSeasons: Int
    public var episodeDurationMinutes: Int
    public var rewatchCount: Int
    public var alertsEnabled: Bool
    public var preferredSourceID: String?
    public var preferredAudioLanguage: String?
    public var preferredSubtitleLanguage: String?
    public var preferredQualityRaw: String?
    public var preferredPlaybackRate: Float?
    public var directorName: String?
    public var studioName: String?
    @Attribute(.externalStorage) public var snapshotData: Data?

    public init(
        mediaID: String,
        title: String,
        originalTitle: String,
        projectTypeRaw: String,
        posterURLString: String? = nil,
        backdropURLString: String? = nil,
        genres: [String] = [],
        releaseYear: Int,
        statusRaw: String? = nil,
        isFavorite: Bool = false,
        inWatchlist: Bool = false,
        personalRating: Double? = nil,
        notes: String = "",
        startDate: Date? = nil,
        finishDate: Date? = nil,
        addedAt: Date = Date(),
        updatedAt: Date = Date(),
        totalEpisodes: Int = 1,
        totalSeasons: Int = 1,
        episodeDurationMinutes: Int = 24,
        rewatchCount: Int = 0,
        alertsEnabled: Bool = false,
        preferredSourceID: String? = nil,
        preferredAudioLanguage: String? = nil,
        preferredSubtitleLanguage: String? = nil,
        preferredQualityRaw: String? = nil,
        preferredPlaybackRate: Float? = nil,
        directorName: String? = nil,
        studioName: String? = nil,
        snapshotData: Data? = nil
    ) {
        self.mediaID = mediaID
        self.title = title
        self.originalTitle = originalTitle
        self.projectTypeRaw = projectTypeRaw
        self.posterURLString = posterURLString
        self.backdropURLString = backdropURLString
        self.genres = genres
        self.releaseYear = releaseYear
        self.statusRaw = statusRaw
        self.isFavorite = isFavorite
        self.inWatchlist = inWatchlist
        self.personalRating = personalRating
        self.notes = notes
        self.startDate = startDate
        self.finishDate = finishDate
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.totalEpisodes = totalEpisodes
        self.totalSeasons = totalSeasons
        self.episodeDurationMinutes = episodeDurationMinutes
        self.rewatchCount = rewatchCount
        self.alertsEnabled = alertsEnabled
        self.preferredSourceID = preferredSourceID
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.preferredQualityRaw = preferredQualityRaw
        self.preferredPlaybackRate = preferredPlaybackRate
        self.directorName = directorName
        self.studioName = studioName
        self.snapshotData = snapshotData
    }

    public var projectType: MediaProjectType {
        get { MediaProjectType(rawValue: projectTypeRaw) ?? .other }
        set { projectTypeRaw = newValue.rawValue }
    }

    public var status: WatchTrackingStatus? {
        get { statusRaw.flatMap(WatchTrackingStatus.init(rawValue:)) }
        set { statusRaw = newValue?.rawValue }
    }

    public var preferredQuality: VideoQualityTier? {
        get { preferredQualityRaw.flatMap(VideoQualityTier.init(rawValue:)) }
        set { preferredQualityRaw = newValue?.rawValue }
    }

    public var posterURL: URL? {
        posterURLString.flatMap(URL.init(string:))
    }

    public var backdropURL: URL? {
        backdropURLString.flatMap(URL.init(string:))
    }

    public var snapshot: MediaItem? {
        get {
            guard let snapshotData else { return nil }
            return try? JSONDecoder().decode(MediaItem.self, from: snapshotData)
        }
        set {
            snapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    public func toDTO() -> LibraryEntryDTO {
        LibraryEntryDTO(
            mediaID: mediaID,
            title: title,
            originalTitle: originalTitle,
            projectTypeRaw: projectTypeRaw,
            posterURLString: posterURLString,
            backdropURLString: backdropURLString,
            genres: genres,
            releaseYear: releaseYear,
            statusRaw: statusRaw,
            isFavorite: isFavorite,
            inWatchlist: inWatchlist,
            personalRating: personalRating,
            notes: notes,
            startDate: startDate,
            finishDate: finishDate,
            addedAt: addedAt,
            updatedAt: updatedAt,
            totalEpisodes: totalEpisodes,
            totalSeasons: totalSeasons,
            episodeDurationMinutes: episodeDurationMinutes,
            rewatchCount: rewatchCount,
            alertsEnabled: alertsEnabled,
            preferredSourceID: preferredSourceID,
            preferredAudioLanguage: preferredAudioLanguage,
            preferredSubtitleLanguage: preferredSubtitleLanguage,
            preferredQualityRaw: preferredQualityRaw
        )
    }
}
