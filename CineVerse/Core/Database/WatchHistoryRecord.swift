import Foundation
import SwiftData

@Model
public final class WatchHistoryRecord {
    public var id: UUID
    public var mediaID: String
    public var title: String
    public var projectTypeRaw: String
    public var genres: [String]
    public var season: Int?
    public var episode: Int?
    public var minutesWatched: Int
    public var watchedAt: Date

    public init(
        id: UUID = UUID(),
        mediaID: String,
        title: String,
        projectTypeRaw: String,
        genres: [String] = [],
        season: Int? = nil,
        episode: Int? = nil,
        minutesWatched: Int,
        watchedAt: Date = Date()
    ) {
        self.id = id
        self.mediaID = mediaID
        self.title = title
        self.projectTypeRaw = projectTypeRaw
        self.genres = genres
        self.season = season
        self.episode = episode
        self.minutesWatched = minutesWatched
        self.watchedAt = watchedAt
    }

    public var projectType: MediaProjectType {
        MediaProjectType(rawValue: projectTypeRaw) ?? .other
    }

    public func toDTO() -> WatchHistoryDTO {
        WatchHistoryDTO(
            id: id,
            mediaID: mediaID,
            title: title,
            projectTypeRaw: projectTypeRaw,
            genres: genres,
            season: season,
            episode: episode,
            minutesWatched: minutesWatched,
            watchedAt: watchedAt
        )
    }
}
