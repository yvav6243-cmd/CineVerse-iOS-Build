import SwiftUI

public struct PlayerControlsOverlay: View {
    let session: PlayerSession
    let isFullscreen: Bool
    let isLocked: Bool
    let scalingMode: VideoScalingMode
    let onSkipIntro: (() -> Void)?
    let onClose: () -> Void
    let onToggleFullscreen: () -> Void
    let onToggleLock: () -> Void
    let onSelectScalingMode: (VideoScalingMode) -> Void
    let onOpenSettings: () -> Void
    let onImportSubtitle: () -> Void
    let onUserInteraction: () -> Void

    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    @State private var showRemainingTime: Bool = false

    public init(
        session: PlayerSession,
        isFullscreen: Bool,
        isLocked: Bool,
        scalingMode: VideoScalingMode,
        onSkipIntro: (() -> Void)? = nil,
        onClose: @escaping () -> Void,
        onToggleFullscreen: @escaping () -> Void,
        onToggleLock: @escaping () -> Void,
        onSelectScalingMode: @escaping (VideoScalingMode) -> Void,
        onOpenSettings: @escaping () -> Void,
        onImportSubtitle: @escaping () -> Void,
        onUserInteraction: @escaping () -> Void
    ) {
        self.session = session
        self.isFullscreen = isFullscreen
        self.isLocked = isLocked
        self.scalingMode = scalingMode
        self.onSkipIntro = onSkipIntro
        self.onClose = onClose
        self.onToggleFullscreen = onToggleFullscreen
        self.onToggleLock = onToggleLock
        self.onSelectScalingMode = onSelectScalingMode
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
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
                    Color.black.opacity(0.68),
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: isFullscreen ? .all : [])
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
                            onSkipIntro()
                            onUserInteraction()
                        } label: {
                            Label("Skip Intro", systemImage: "forward.end.fill")
                                .font(CVFont.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(CVColor.brandGradient, in: Capsule(style: .continuous))
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
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
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(session.selection.mediaItem.localizedTitle)
                        .font(isFullscreen ? CVFont.cardTitle : CVFont.caption.weight(.bold))
                        .lineLimit(1)

                    if session.engine.playbackState != .playing {
                        statusBadgePill
                    }
                }

                if let ep = session.selection.episode {
                    Text("S\(ep.seasonNumber) E\(ep.episodeNumber) · \(ep.title)")
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
                    session.pipController.toggle()
                    onUserInteraction()
                } label: {
                    Image(systemName: session.pipController.isActive ? "pip.exit" : "pip.enter")
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Picture in Picture")
            }

            if isFullscreen {
                AirPlayButton()
                    .frame(width: 32, height: 32)
                    .cvGlass(Circle(), interactive: true)
            }

            Button {
                onOpenSettings()
                onUserInteraction()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Player settings")
        }
    }

    private var statusBadgePill: some View {
        let state = session.engine.playbackState
        let tint: Color = {
            switch state {
            case .failed: return CVColor.danger
            case .buffering, .loading: return CVColor.warning
            case .paused: return .white.opacity(0.85)
            case .ready, .playing: return CVColor.success
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(state.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.45), in: Capsule(style: .continuous))
    }

    private var centerTransport: some View {
        VStack(spacing: 6) {
            HStack(spacing: isFullscreen ? CVSpacing.xxl + 6 : CVSpacing.xl) {
                Button {
                    Haptics.impact(.light)
                    session.engine.skip(by: -10)
                    onUserInteraction()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: isFullscreen ? 23 : 18, weight: .semibold))
                        .frame(width: isFullscreen ? 50 : 42, height: isFullscreen ? 50 : 42)
                        .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rewind 10 seconds")

                Button {
                    Haptics.impact(.medium)
                    session.engine.togglePlayPause()
                    onUserInteraction()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.28))
                        if session.engine.isBuffering {
                            ProgressView()
                                .tint(.white.opacity(0.75))
                                .scaleEffect(isFullscreen ? 1.5 : 1.25)
                        }
                        Image(systemName: session.engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isFullscreen ? 26 : 21, weight: .bold))
                            .offset(x: session.engine.isPlaying ? 0 : 2)
                    }
                    .frame(width: isFullscreen ? 64 : 52, height: isFullscreen ? 64 : 52)
                    .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(session.engine.isPlaying ? "Pause" : "Play")

                Button {
                    Haptics.impact(.light)
                    session.engine.skip(by: 10)
                    onUserInteraction()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: isFullscreen ? 23 : 18, weight: .semibold))
                        .frame(width: isFullscreen ? 50 : 42, height: isFullscreen ? 50 : 42)
                        .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Forward 10 seconds")
            }

            if session.engine.isBuffering || session.engine.playbackState == .loading {
                Text(session.engine.playbackState.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .allowsHitTesting(false)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 5) {
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
                    HStack(spacing: 3) {
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
        HStack(spacing: 5) {
            audioMenu
            subtitleMenu
            qualityMenu
            scalingModeMenu

            if isFullscreen {
                speedMenu
                Button {
                    Haptics.impact(.light)
                    onToggleLock()
                } label: {
                    quickIconLabel("lock.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lock screen")
            }

            Button {
                Haptics.impact(.medium)
                onToggleFullscreen()
                onUserInteraction()
            } label: {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 28)
                    .background(CVColor.iris.opacity(0.85), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFullscreen ? "Exit Fullscreen" : "Fullscreen")
        }
    }

    private var scalingModeMenu: some View {
        Menu {
            ForEach(VideoScalingMode.allCases) { mode in
                Button {
                    Haptics.selection()
                    onSelectScalingMode(mode)
                } label: {
                    HStack {
                        Label(mode.rawValue, systemImage: mode.symbolName)
                        if scalingMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: scalingMode.symbolName)
                if isFullscreen {
                    Text(scalingMode.rawValue)
                }
            }
            .font(CVFont.micro.weight(.semibold))
            .padding(.horizontal, 7)
            .frame(height: 28)
            .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Video scaling mode")
    }

    private var qualityMenu: some View {
        Menu {
            ForEach(session.engine.availableQualities) { quality in
                Button {
                    session.selectQuality(quality)
                    onUserInteraction()
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
                .padding(.horizontal, 7)
                .frame(height: 28)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Quality selector")
    }

    private var audioMenu: some View {
        Menu {
            ForEach(session.engine.availableAudioTracks) { track in
                Button {
                    session.selectAudio(track)
                    onUserInteraction()
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
            .padding(.horizontal, 7)
            .frame(height: 28)
            .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Audio track selector")
    }

    private var subtitleMenu: some View {
        Menu {
            Button {
                session.selectSubtitle(nil)
                onUserInteraction()
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
                    session.selectSubtitle(sub)
                    onUserInteraction()
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
                .frame(width: 30, height: 28)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Subtitles selector")
    }

    private var speedMenu: some View {
        Menu {
            ForEach(availableRates, id: \.self) { rate in
                Button {
                    session.engine.setRate(rate)
                    onUserInteraction()
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
                .padding(.horizontal, 7)
                .frame(height: 28)
                .cvGlass(Capsule(style: .continuous), interactive: true)
        }
        .accessibilityLabel("Playback speed")
    }

    private func quickIconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .frame(width: 30, height: 28)
            .cvGlass(Capsule(style: .continuous), interactive: true)
    }
}
