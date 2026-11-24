import Foundation
import ActivityKit

public struct PlaybackActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var isPlaying: Bool
        public var elapsedSeconds: Double
        public var durationSeconds: Double
        public var updatedAt: Date

        public init(
            isPlaying: Bool,
            elapsedSeconds: Double,
            durationSeconds: Double,
            updatedAt: Date = Date()
        ) {
            self.isPlaying = isPlaying
            self.elapsedSeconds = elapsedSeconds
            self.durationSeconds = durationSeconds
            self.updatedAt = updatedAt
        }

        public var progressFraction: Double {
            guard durationSeconds > 1 else { return 0 }
            return min(max(elapsedSeconds / durationSeconds, 0), 1)
        }

        public var remainingSeconds: Double {
            max(0, durationSeconds - elapsedSeconds)
        }
    }

    public let title: String
    public let episodeCode: String?
    public let symbolName: String

    public init(title: String, episodeCode: String?, symbolName: String) {
        self.title = title
        self.episodeCode = episodeCode
        self.symbolName = symbolName
    }
}
