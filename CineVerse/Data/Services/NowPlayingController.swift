import Foundation
import MediaPlayer
import UIKit

@MainActor
public final class NowPlayingController {
    private var commandTokens: [(command: MPRemoteCommand, target: Any)] = []

    public init() {}

    public func configureRemoteCommands(
        onPlay: @escaping @MainActor () -> Void,
        onPause: @escaping @MainActor () -> Void,
        onToggle: @escaping @MainActor () -> Void,
        onSkipForward: @escaping @MainActor (TimeInterval) -> Void,
        onSkipBackward: @escaping @MainActor (TimeInterval) -> Void,
        onSeek: @escaping @MainActor (TimeInterval) -> Void
    ) {
        clearRemoteCommands()
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        let playTarget = center.playCommand.addTarget { _ in
            Task { @MainActor in onPlay() }
            return .success
        }
        commandTokens.append((center.playCommand, playTarget))

        center.pauseCommand.isEnabled = true
        let pauseTarget = center.pauseCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }
        commandTokens.append((center.pauseCommand, pauseTarget))

        center.togglePlayPauseCommand.isEnabled = true
        let toggleTarget = center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in onToggle() }
            return .success
        }
        commandTokens.append((center.togglePlayPauseCommand, toggleTarget))

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [10]
        let fwdTarget = center.skipForwardCommand.addTarget { event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            Task { @MainActor in onSkipForward(interval) }
            return .success
        }
        commandTokens.append((center.skipForwardCommand, fwdTarget))

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [10]
        let bwdTarget = center.skipBackwardCommand.addTarget { event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            Task { @MainActor in onSkipBackward(interval) }
            return .success
        }
        commandTokens.append((center.skipBackwardCommand, bwdTarget))

        center.changePlaybackPositionCommand.isEnabled = true
        let seekTarget = center.changePlaybackPositionCommand.addTarget { event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetTime = posEvent.positionTime
            Task { @MainActor in onSeek(targetTime) }
            return .success
        }
        commandTokens.append((center.changePlaybackPositionCommand, seekTarget))
    }

    public func updateMetadata(
        title: String,
        subtitle: String?,
        artwork: UIImage?,
        elapsed: TimeInterval,
        duration: TimeInterval,
        rate: Float,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration: max(duration, 0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0
        ]
        if let subtitle {
            info[MPMediaItemPropertyAlbumTitle] = subtitle
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func clearRemoteCommands() {
        for pair in commandTokens {
            pair.command.removeTarget(pair.target)
        }
        commandTokens.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
