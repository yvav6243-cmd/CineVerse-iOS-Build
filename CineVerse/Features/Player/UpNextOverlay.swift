import SwiftUI

public struct UpNextOverlay: View {
    let nextEpisode: MediaEpisode
    let hasPlayableSource: Bool
    let countdownSeconds: Int
    let autoplayEnabled: Bool
    let onPlayNext: () -> Void
    let onAddSource: () -> Void
    let onDismiss: () -> Void

    public init(
        nextEpisode: MediaEpisode,
        hasPlayableSource: Bool,
        countdownSeconds: Int,
        autoplayEnabled: Bool,
        onPlayNext: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.nextEpisode = nextEpisode
        self.hasPlayableSource = hasPlayableSource
        self.countdownSeconds = countdownSeconds
        self.autoplayEnabled = autoplayEnabled
        self.onPlayNext = onPlayNext
        self.onAddSource = onAddSource
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: CVSpacing.sm) {
                    HStack {
                        Label("Up Next", systemImage: "play.square.stack")
                            .font(CVFont.caption.weight(.bold))
                            .foregroundStyle(CVColor.iris)
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(nextEpisode.formattedCode) · \(nextEpisode.title)")
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if hasPlayableSource {
                        if autoplayEnabled {
                            Text("Starting in \(countdownSeconds)s")
                                .font(CVFont.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .monospacedDigit()
                        }

                        HStack(spacing: CVSpacing.xs) {
                            Button("Play Now", action: onPlayNext)
                                .buttonStyle(CVPrimaryButtonStyle(compact: true))
                            Button("Cancel", action: onDismiss)
                                .buttonStyle(CVGlassButtonStyle(compact: true))
                        }
                    } else {
                        Text("No video source configured for this episode.")
                            .font(CVFont.caption)
                            .foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: CVSpacing.xs) {
                            Button("Add Source", action: onAddSource)
                                .buttonStyle(CVPrimaryButtonStyle(compact: true))
                            Button("Dismiss", action: onDismiss)
                                .buttonStyle(CVGlassButtonStyle(compact: true))
                        }
                    }
                }
                .padding(CVSpacing.md)
                .frame(maxWidth: 320)
                .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
            }
            .padding(CVSpacing.lg)
        }
    }
}
