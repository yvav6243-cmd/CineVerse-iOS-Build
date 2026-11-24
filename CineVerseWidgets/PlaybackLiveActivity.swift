import SwiftUI
import WidgetKit
import ActivityKit

public struct PlaybackLiveActivity: Widget {
    public init() {}

    private let irisColor = Color(red: 110 / 255, green: 91 / 255, blue: 1.0)

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.84))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.attributes.symbolName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(irisColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            if let code = context.attributes.episodeCode {
                                Text(code)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(irisColor)
                        Text("-\(formatDuration(context.state.remainingSeconds))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progressFraction)
                            .tint(irisColor)

                        HStack {
                            Text(formatDuration(context.state.elapsedSeconds))
                            Spacer()
                            Text(formatDuration(context.state.durationSeconds))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(irisColor)
            } compactTrailing: {
                Text(formatCompactRemaining(context.state.remainingSeconds))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(irisColor)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<PlaybackActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: context.attributes.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(irisColor)
                    .frame(width: 34, height: 34)
                    .background(irisColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let episodeCode = context.attributes.episodeCode {
                            Text(episodeCode)
                                .fontWeight(.medium)
                            Text("•")
                        }
                        Text(context.state.isPlaying ? "Playing" : "Paused")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(irisColor)
            }

            ProgressView(value: context.state.progressFraction)
                .tint(irisColor)

            HStack {
                Text(formatDuration(context.state.elapsedSeconds))
                Spacer()
                Text("-\(formatDuration(context.state.remainingSeconds))")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.75))
            .monospacedDigit()
        }
        .padding(14)
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatCompactRemaining(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN && seconds > 0 else { return "0m" }
        let mins = Int((seconds / 60.0).rounded(.up))
        if mins >= 60 {
            return "\(mins / 60)h"
        }
        return "\(max(1, mins))m"
    }
}
