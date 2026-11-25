import SwiftUI

public struct PlayerControlsOverlay: View {
    let session: PlayerSession
    let isLocked: Bool
    let isAspectFill: Bool
    let onClose: () -> Void
    let onToggleLock: () -> Void
    let onToggleAspectFill: () -> Void
    let onOpenSettings: () -> Void
    let onImportSubtitle: () -> Void
    let onUserInteraction: () -> Void

    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    @State private var showRemainingTime: Bool = false

    public init(
        session: PlayerSession,
        isLocked: Bool,
        isAspectFill: Bool,
        onClose: @escaping () -> Void,
        onToggleLock: @escaping () -> Void,
        onToggleAspectFill: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onImportSubtitle: @escaping () -> Void,
        onUserInteraction: @escaping () -> Void
    ) {
        self.session = session
        self.isLocked = isLocked
        self.isAspectFill = isAspectFill
        self.onClose = onClose
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
                    Label("Unlock", systemImage: "lock.open.fill")
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
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                centerTransport
                Spacer()
                bottomBar
            }
            .padding(.horizontal, CVSpacing.md)
            .padding(.vertical, CVSpacing.sm)
        }
    }

    private var topBar: some View {
        HStack(spacing: CVSpacing.sm) {
            Button {
                Haptics.impact(.light)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.selection.mediaItem.localizedTitle)
                    .font(CVFont.cardTitle)
                    .lineLimit(1)
                if let ep = session.selection.episode {
                    Text("\(ep.formattedCode) · \(ep.title)")
                        .font(CVFont.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                } else {
                    Text(session.selection.source.providerName)
                        .font(CVFont.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
            }

            Spacer()

            if session.pipController.isSupported {
                Button {
                    onUserInteraction()
                    session.pipController.toggle()
                } label: {
                    Image(systemName: session.pipController.isActive ? "pip.exit" : "pip.enter")
                        .font(.body.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .cvGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Picture in Picture")
            }

            AirPlayButton()
                .frame(width: 38, height: 38)
                .cvGlass(Circle(), interactive: true)

            Button {
                onUserInteraction()
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playback settings")
        }
    }

    private var centerTransport: some View {
        HStack(spacing: CVSpacing.xxl + 8) {
            Button {
                onUserInteraction()
                Haptics.impact(.light)
                session.engine.skip(by: -10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 56, height: 56)
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
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: session.engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .offset(x: session.engine.isPlaying ? 0 : 2)
                    }
                }
                .frame(width: 74, height: 74)
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
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip forward 10 seconds")
        }
    }

    private var bottomBar: some View {
        VStack(spacing: CVSpacing.xs) {
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

            HStack(spacing: CVSpacing.xs) {
                Button {
                    Haptics.selection()
                    showRemainingTime.toggle()
                    onUserInteraction()
                } label: {
                    HStack(spacing: 4) {
                        Text(session.engine.currentTime.formattedPlaybackTime)
                            .foregroundStyle(.white)
                        Text("/")
                            .foregroundStyle(.white.opacity(0.5))
                        if showRemainingTime && session.engine.duration > session.engine.currentTime {
                            Text("-\((session.engine.duration - session.engine.currentTime).formattedPlaybackTime)")
                                .foregroundStyle(.white.opacity(0.8))
                        } else {
                            Text(session.engine.duration.formattedPlaybackTime)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(session.engine.isReady ? CVColor.success : CVColor.warning)
                        .frame(width: 6, height: 6)
                    Text(session.engine.diagnostics.compactSummary)
                        .font(CVFont.micro)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            }
            .font(CVFont.caption.weight(.medium))
            .monospacedDigit()

            ScrollView(.horizontal, showsIndicators: false) {
                quickMenusRow
                    .padding(.vertical, 2)
            }
        }
    }

    private var quickMenusRow: some View {
        HStack(spacing: CVSpacing.xs) {
            if session.alternativeSources.count > 1 {
                Menu {
                    ForEach(session.alternativeSources) { src in
                        Button {
                            onUserInteraction()
                            Task { await session.switchSource(to: src) }
                        } label: {
                            HStack {
                                Text("\(src.providerName) (\(src.format.badgeText))")
                                if src.id == session.selection.source.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sources (\(session.alternativeSources.count))", systemImage: "play.tv")
                        .font(CVFont.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                }
            }

            if !session.engine.availableQualities.isEmpty {
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
                    Label(session.engine.selectedQuality?.tier.rawValue ?? "Auto", systemImage: "dial.high")
                        .font(CVFont.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                }
            }

            Menu {
                ForEach(availableRates, id: \.self) { rate in
                    Button {
                        onUserInteraction()
                        session.engine.setRate(rate)
                    } label: {
                        HStack {
                            Text(rate == 1.0 ? "1.0x (Normal)" : String(format: "%.2gx", rate))
                            if session.engine.playbackRate == rate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(String(format: "%.2gx", session.engine.playbackRate))
                    .font(CVFont.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .cvGlass(Capsule(style: .continuous), interactive: true)
            }

            if session.engine.availableAudioTracks.count > 1 {
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
                    Image(systemName: "waveform")
                        .frame(width: 34, height: 32)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                }
            }

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
                Button {
                    onImportSubtitle()
                } label: {
                    Label("Import .srt / .vtt File", systemImage: "doc.badge.plus")
                }
            } label: {
                Image(systemName: session.engine.selectedSubtitleTrack == nil ? "captions.bubble" : "captions.bubble.fill")
                    .frame(width: 34, height: 32)
                    .cvGlass(Capsule(style: .continuous), interactive: true)
            }

            Menu {
                ForEach(VideoPicturePreset.allCases) { preset in
                    Button {
                        onUserInteraction()
                        session.picturePreset = preset
                    } label: {
                        HStack {
                            Label(preset.rawValue, systemImage: preset.symbolName)
                            if session.picturePreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: session.picturePreset.symbolName)
                    .frame(width: 34, height: 32)
                    .cvGlass(Capsule(style: .continuous), interactive: true)
            }
            .accessibilityLabel("Picture Enhancement")

            Button { onUserInteraction(); onToggleAspectFill() } label: {
                quickIconLabel(isAspectFill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle fill mode")

            Button { Haptics.impact(.light); onToggleLock() } label: {
                quickIconLabel("lock")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lock controls")

            Button { onUserInteraction(); OrientationController.shared.toggleLandscape() } label: {
                quickIconLabel("rotate.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rotate screen")
        }
    }

    private func quickIconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .frame(width: 34, height: 32)
            .cvGlass(Capsule(style: .continuous), interactive: true)
    }
}
