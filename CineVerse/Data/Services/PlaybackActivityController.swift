import Foundation
import ActivityKit

@MainActor
public final class PlaybackActivityController {
    private var activity: Activity<PlaybackActivityAttributes>?
    private var lastUpdateDate: Date = .distantPast
    private var lastPlayingState: Bool?

    public init() {}

    public func start(
        title: String,
        episodeCode: String?,
        symbolName: String,
        elapsed: TimeInterval,
        duration: TimeInterval
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await endImmediate()
            let attributes = PlaybackActivityAttributes(
                title: title,
                episodeCode: episodeCode,
                symbolName: symbolName
            )
            let state = PlaybackActivityAttributes.ContentState(
                isPlaying: true,
                elapsedSeconds: elapsed,
                durationSeconds: duration,
                updatedAt: Date()
            )
            let content = ActivityContent(state: state, staleDate: nil)
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                lastUpdateDate = Date()
                lastPlayingState = true
            } catch {
                CVLogger.player.debug("Live Activity start skipped: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    public func update(isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval, force: Bool = false) {
        guard let activity else { return }
        let now = Date()
        let playStateChanged = lastPlayingState != isPlaying
        guard force || playStateChanged || now.timeIntervalSince(lastUpdateDate) >= 15 else {
            return
        }

        lastUpdateDate = now
        lastPlayingState = isPlaying
        let state = PlaybackActivityAttributes.ContentState(
            isPlaying: isPlaying,
            elapsedSeconds: elapsed,
            durationSeconds: duration,
            updatedAt: now
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    public func end() {
        Task {
            await endImmediate()
        }
    }

    private func endImmediate() async {
        if let active = activity {
            await active.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
        lastPlayingState = nil
    }
}
