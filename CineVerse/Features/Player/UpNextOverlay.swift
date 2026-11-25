import SwiftUI

public struct UpNextOverlay: View {
    let nextEpisode: MediaEpisode
    let fallbackPosterURL: URL?
    let hasPlayableSource: Bool
    let countdownSeconds: Int
    let autoplayEnabled: Bool
    let onToggleAutoplay: () -> Void
    let onPlayNext: () -> Void
    let onAddSource: () -> Void
    let onDismiss: () -> Void

    public init(
        nextEpisode: MediaEpisode,
        fallbackPosterURL: URL? = nil,
        hasPlayableSource: Bool,
        countdownSeconds: Int,
        autoplayEnabled: Bool,
        onToggleAutoplay: @escaping () -> Void,
        onPlayNext: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.nextEpisode = nextEpisode
        self.fallbackPosterURL = fallbackPosterURL
        self.hasPlayableSource = hasPlayableSource
        self.countdownSeconds = countdownSeconds
        self.autoplayEnabled = autoplayEnabled
        self.onToggleAutoplay = onToggleAutoplay
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
                        Label("Next Episode", systemImage: "play.square.stack")
                            .font(CVFont.caption.weight(.bold))
                            .foregroundStyle(CVColor.iris)
                        Spacer()
                        Button(action: onToggleAutoplay) {
                            HStack(spacing: 4) {
                                Image(systemName: autoplayEnabled ? "bolt.fill" : "bolt.slash")
                                Text(autoplayEnabled ? "Auto On" : "Auto Off")
                            }
                            .font(CVFont.micro)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.14), in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: CVSpacing.sm) {
                        CachedAsyncImage(
                            url: nextEpisode.stillImageURL ?? fallbackPosterURL,
                            targetSize: CGSize(width: 200, height: 112),
                            fallbackSymbol: "tv"
                        )
                        .frame(width: 96, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(nextEpisode.formattedCode) · \(nextEpisode.title)")
                                .font(CVFont.cardTitle)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if nextEpisode.durationMinutes > 0 {
                                Text("\(nextEpisode.durationMinutes) min")
                                    .font(CVFont.micro)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }

                    if hasPlayableSource {
                        if autoplayEnabled {
                            Text("Playing next episode in \(countdownSeconds)s")
                                .font(CVFont.caption)
                                .foregroundStyle(.white.opacity(0.78))
                                .monospacedDigit()
                        }

                        HStack(spacing: CVSpacing.xs) {
                            Button("Play Next", action: onPlayNext)
                                .buttonStyle(CVPrimaryButtonStyle(compact: true))
                            Button("Cancel", action: onDismiss)
                                .buttonStyle(CVGlassButtonStyle(compact: true))
                        }
                    } else {
                        Text("No open stream configured for \(nextEpisode.formattedCode).")
                            .font(CVFont.caption)
                            .foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: CVSpacing.xs) {
                            Button("Attach Stream", action: onAddSource)
                                .buttonStyle(CVPrimaryButtonStyle(compact: true))
                            Button("Dismiss", action: onDismiss)
                                .buttonStyle(CVGlassButtonStyle(compact: true))
                        }
                    }
                }
                .padding(CVSpacing.md)
                .frame(maxWidth: 345)
                .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
            }
            .padding(CVSpacing.lg)
        }
    }
}
