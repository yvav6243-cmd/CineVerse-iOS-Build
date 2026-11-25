import SwiftUI

public struct PlayerControlsOverlay: View {
    let session: PlayerSession
    let isFullscreen: Bool
    let isLocked: Bool
    let isAspectFill: Bool
    let onSkipIntro: (() -> Void)?
    let onClose: () -> Void
    let onToggleFullscreen: () -> Void
    let onToggleLock: () -> Void
    let onToggleAspectFill: () -> Void
    let onOpenSettings: () -> Void
    let onImportSubtitle: () -> Void
    let onUserInteraction: () -> Void

    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    @State private var showRemainingTime: Bool = false

    public init(
        session: PlayerSession,
        isFullscreen: Bool,
        isLocked: Bool,
        isAspectFill: Bool,
        onSkipIntro: (() -> Void)? = nil,
        onClose: @escaping () -> Void,
        onToggleFullscreen: @escaping () -> Void,
        onToggleLock: @escaping () -> Void,
        onToggleAspectFill: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onImportSubtitle: @escaping () -> Void,
        onUserInteraction: @escaping () -> Void
    ) {
        self.session = session
        self.isFullscreen = isFullscreen
        self.isLocked = isLocked
        self.isAspectFill = isAspectFill
        self.onSkipIntro = onSkipIntro
        self.onClose = onClose
        self.onToggleFullscreen = onToggleFullscreen
        self.onToggleLock = onToggleLock
        self.onToggleAspectFill = onToggleAspectFill
        self.onOpenSettings = onOpenSettings
        self.onImportSubtitle = onImportSubtitle
        self.onUserInteraction = onUserInteraction
    }

    public var body: some View {
        ZStack {
            if isLocked {
                lockedOverlay
            } else {
                fullControlsOverlay
            }
        }
        .foregroundStyle(.white)
    }

    private var lockedOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    Haptics.impact(.medium)
                    onToggleLock()
                } label: {
                    Label("Unlock Screen", systemImage: "lock.open.fill")
                        .font(CVFont.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CVSpacing.md)
            .padding(.top, CVSpacing.sm)
            Spacer()
        }
    }

    private var fullControlsOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 4)
                centerTransport
                Spacer(minLength: 4)
                if let onSkipIntro {
                    HStack {
                        Spacer()
                        Button {
                            Haptics.impact(.medium)
                            onUserInteraction()
                            onSkipIntro()
                        } label: {
                            Label("Skip Intro", systemImage: "forward.end.fill")
                                .font(CVFont.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(CVColor.brandGradient, in: Capsule(style: .continuous))
                                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, CVSpacing.xs)
                }
                bottomBar
            }
            .padding(.horizontal, isFullscreen ? CVSpacing.md : CVSpacing.sm)
            .padding(.vertical, isFullscreen ? CVSpacing.sm : CVSpacing.xs)
        }
    }

    private var topBar: some View {
        HStack(spacing: CVSpacing.xs) {
            Button {
                Haptics.impact(.light)
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .frame(width: 36, height: 36)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.selection.mediaItem.localizedTitle)
                    .font(isFullscreen ? CVFont.cardTitle : CVFont.caption.weight(.bold))
                    .lineLimit(1)
                if let ep = session.selection.episode {
                    Text("Season \(ep.seasonNumber) · Episode \(ep.episodeNumber) — \(ep.title)")
                        .font(CVFont.micro)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                } else {
                    Text("\(session.selection.source.providerName) · \(session.engine.diagnostics.compactSummary)")
                        .font(CVFont.micro)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if !session.engine.usesWebSurface && session.pipController.isSupported {
                Button {
                    onUserInteraction()
                    session.pipController.toggle()
                } label: {
                    Image(systemName: session.pipController.isActive ? "pip.exit" : "pip.enter")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Picture in Picture")
            }

            if isFullscreen {
                AirPlayButton()
                    .frame(width: 34, height: 34)
                    .cvGlass(Circle(), interactive: true)
            }

            Button {
                onUserInteraction()
                onOpenSettings()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Additional settings")
        }
    }

    private var centerTransport: some View {
        HStack(spacing: isFullscreen ? CVSpacing.xxl + 8 : CVSpacing.xl) {
            Button {
                onUserInteraction()
                Haptics.impact(.light)
                session.engine.skip(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: isFullscreen ? 25 : 20, weight: .semibold))
                    .frame(width: isFullscreen ? 54 : 44, height: isFullscreen ? 54 : 44)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rewind 10 seconds")

            Button {
                onUserInteraction()
                Haptics.impact(.medium)
                session.engine.togglePlayPause()
            } label: {
                ZStack {
                    if session.engine.isBuffering {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.15)
                    } else {
                        Image(systemName: session.engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isFullscreen ? 30 : 24, weight: .bold))
                            .offset(x: session.engine.isPlaying ? 0 : 2)
                    }
                }
                .frame(width: isFullscreen ? 70 : 56, height: isFullscreen ? 70 : 56)
                .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.engine.isPlaying ? "Pause" : "Play")

            Button {
                onUserInteraction()
                Haptics.impact(.light)
                session.engine.skip(by: 10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: isFullscreen ? 25 : 20, weight: .semibold))
                    .frame(width: isFullscreen ? 54 : 44, height: isFullscreen ? 54 : 44)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Forward 10 seconds")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            PlaybackScrubber(
                currentTime: session.engine.currentTime,
                bufferedTime: session.engine.bufferedTime,
                duration: session.engine.duration,
                onEditingChanged: { editing in
                    session.engine.isSeeking = editing
                    onUserInteraction()
                },
                onSeek: { target in
                    session.engine.seek(to: target, exact: true)
                    onUserInteraction()
                }
            )

            HStack(spacing: 6) {
                Button {
                    Haptics.selection()
                    showRemainingTime.toggle()
                    onUserInteraction()
                } label: {
                    HStack(spacing: 4) {
                        Text(session.engine.currentTime.formattedPlaybackTime)
                            .foregroundStyle(.white)
                        Text("/")
                            .foregroundStyle(.white.opacity(0.55))
                        if showRemainingTime && session.engine.duration > session.engine.currentTime {
                            Text("-\((session.engine.duration - session.engine.currentTime).formattedPlaybackTime)")
                                .foregroundStyle(.white.opacity(0.85))
                        } else {
                            Text(session.engine.duration.formattedPlaybackTime)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .font(CVFont.micro.weight(.semibold))
                    .monospacedDigit()
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                bottomActionButtons
            }
        }
    }

    private var bottomActionButtons: some View {
        HStack(spacing: 6) {
            Button {
                onUserInteraction()
                onOpenSettings()
            } label: {
                quickIconLabel("gearshape.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            qualityMenu
            audioMenu
            subtitleMenu

            if isFullscreen {
                speedMenu
                Button { onUserInteraction(); onToggleAspectFill() } label: {
                    quickIconLabel(isAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aspect ratio fit or fill")

                Button { Haptics.impact(.light); onToggleLock() } label: {
                    quickIconLabel("lock.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lock screen")
            }

            Button {
                Haptics.impact(.medium)
                onUserInteraction()
                onToggleFullscreen()
            } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .frame(width: 34, height: 30)
                    .background(CVColor.iris.opacity(0.85), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFullscreen ? "Exit Fullscreen" : "Fullscreen")
        }
    }

    private var qualityMenu: some View {
        Menu {
            ForEach(session.engine.availableQualities) { quality in
                Button {
                    onUserInteraction()
                    session.selectQuality(quality)
                } label: {
                    HStack {
                        Text(quality.detailedLabel)
                        if session.engine.selectedQuality?.id == quality.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(session.engine.selectedQuality?.tier.shortBadge ?? "Auto")
                .font(CVFont.micro.weight(.bold))
                .padding(.horizontal, 8)
                .frame(height: 30)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Quality selector")
    }

    private var audioMenu: some View {
        Menu {
            ForEach(session.engine.availableAudioTracks) { track in
                Button {
                    onUserInteraction()
                    session.selectAudio(track)
                } label: {
                    HStack {
                        Text(track.fullLabel)
                        if session.engine.selectedAudioTrack?.id == track.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "waveform")
                if let code = session.engine.selectedAudioTrack?.languageCode.uppercased(), isFullscreen {
                    Text(code)
                }
            }
            .font(CVFont.micro.weight(.semibold))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Audio track selector")
    }

    private var subtitleMenu: some View {
        Menu {
            Button {
                onUserInteraction()
                session.selectSubtitle(nil)
            } label: {
                HStack {
                    Text("Off")
                    if session.engine.selectedSubtitleTrack == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            ForEach(session.engine.availableSubtitles) { sub in
                Button {
                    onUserInteraction()
                    session.selectSubtitle(sub)
                } label: {
                    HStack {
                        Text("\(sub.displayName) (\(sub.format.rawValue))")
                        if session.engine.selectedSubtitleTrack?.id == sub.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button { onImportSubtitle() } label: {
                Label("Import .srt / .vtt File", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: session.engine.selectedSubtitleTrack == nil ? "captions.bubble" : "captions.bubble.fill")
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 30)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Subtitles selector")
    }

    private var speedMenu: some View {
        Menu {
            ForEach(availableRates, id: \.self) { rate in
                Button {
                    onUserInteraction()
                    session.engine.setRate(rate)
                } label: {
                    HStack {
                        Text(rate == 1.0 ? "1x (Normal)" : String(format: "%.2gx", rate))
                        if session.engine.playbackRate == rate {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(String(format: "%.2gx", session.engine.playbackRate))
                .font(CVFont.micro.weight(.semibold))
                .padding(.horizontal, 8)
                .frame(height: 30)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Playback speed")
    }

    private func quickIconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .frame(width: 32, height: 30)
            .cvGlass(Capsule(style: .continuous), interactive: true)
    }
}
