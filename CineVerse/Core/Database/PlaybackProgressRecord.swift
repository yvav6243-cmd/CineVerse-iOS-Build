import Foundation
import SwiftData

@Model
public final class PlaybackProgressRecord {
    @Attribute(.unique) public var key: String
    public var mediaID: String
    public var season: Int
    public var episode: Int
    public var episodeTitle: String
    public var positionSeconds: Double
    public var durationSeconds: Double
    public var isWatched: Bool
    public var watchedAt: Date?
    public var lastUpdated: Date
    public var sourceID: String?

    public init(
        mediaID: String,
        season: Int = 0,
        episode: Int = 0,
        episodeTitle: String = "",
        positionSeconds: Double = 0,
        durationSeconds: Double = 0,
        isWatched: Bool = false,
        watchedAt: Date? = nil,
        lastUpdated: Date = Date(),
        sourceID: String? = nil
    ) {
        self.key = Self.makeKey(mediaID: mediaID, season: season, episode: episode)
        self.mediaID = mediaID
        self.season = season
        self.episode = episode
        self.episodeTitle = episodeTitle
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.isWatched = isWatched
        self.watchedAt = watchedAt
        self.lastUpdated = lastUpdated
        self.sourceID = sourceID
    }

    public static func makeKey(mediaID: String, season: Int, episode: Int) -> String {
        "\(mediaID)|s\(season)|e\(episode)"
    }

    public var fraction: Double {
        guard durationSeconds > 1 else { return isWatched ? 1.0 : 0.0 }
        return min(max(positionSeconds / durationSeconds, 0.0), 1.0)
    }

    public var remainingSeconds: TimeInterval {
        max(0, durationSeconds - positionSeconds)
    }

    public func toDTO() -> PlaybackProgressDTO {
        PlaybackProgressDTO(
            key: key,
            mediaID: mediaID,
            season: season,
            episode: episode,
            episodeTitle: episodeTitle,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            isWatched: isWatched,
            watchedAt: watchedAt,
            lastUpdated: lastUpdated,
            sourceID: sourceID
        )
    }
}
