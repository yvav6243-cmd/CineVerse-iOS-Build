import SwiftUI
import AVFoundation
import UIKit
import UniformTypeIdentifiers

private enum ActivePlayerDragMode {
    case brightness(initial: CGFloat)
    case volume(initial: Float)
    case horizontalSeek(initialTime: TimeInterval)
}

public struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: PlayerSession
    @State private var isFullscreen: Bool = false
    @State private var controlsVisible: Bool = true
    @State private var isLocked: Bool = false
    @State private var scalingMode: VideoScalingMode = .fit
    @State private var showSettingsSheet: Bool = false
    @State private var showSubtitleImporter: Bool = false
    @State private var showAddNextSourceSheet: Bool = false
    @State private var skipIndicatorText: String?
    @State private var gestureHUD: (symbol: String, title: String, fraction: Double)?
    @State private var activeDragMode: ActivePlayerDragMode?
    @State private var pendingTouchSeekTarget: TimeInterval?
    @State private var isHoldBoostingSpeed: Bool = false
    @State private var preHoldRate: Float = 1.0
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var hudDismissTask: Task<Void, Never>?

    private let sourceManager: VideoSourceManager
    private let httpClient: HTTPClient
    private let settingsStore: SettingsStore

    public init(
        selection: PreWatchPlaybackSelection,
        httpClient: HTTPClient,
        progressRepository: ProgressRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol,
        trackerService: TrackerService,
        sourceManager: VideoSourceManager,
        settingsStore: SettingsStore
    ) {
        self.sourceManager = sourceManager
        self.httpClient = httpClient
        self.settingsStore = settingsStore
        _session = State(initialValue: PlayerSession(
            selection: selection, httpClient: httpClient,
            progressRepository: progressRepository, libraryRepository: libraryRepository,
            trackerService: trackerService, sourceManager: sourceManager, settingsStore: settingsStore
        ))
    }

    public var body: some View {
        GeometryReader { rootProxy in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if isFullscreen {
                        videoStageContainer
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        videoStageContainer
                            .frame(maxWidth: .infinity)
                            .frame(height: inlineStageHeight(for: rootProxy.size))
                            .background(Color.black)

                        PlayerInlineDeckView(
                            session: session,
                            scalingMode: scalingMode,
                            onSelectScalingMode: { scalingMode = $0 },
                            onEnterFullscreen: { toggleFullscreen() },
                            onOpenSettings: { showSettingsSheet = true }
                        )
                    }
                }

                if session.showUpNextOverlay, let nextEp = session.nextEpisode {
                    UpNextOverlay(
                        nextEpisode: nextEp,
                        fallbackPosterURL: session.selection.mediaItem.backdropURL ?? session.selection.mediaItem.posterURL,
                        hasPlayableSource: session.nextSelection != nil,
                        countdownSeconds: session.upNextCountdown,
                        autoplayEnabled: settingsStore.autoplayNext,
                        onToggleAutoplay: { settingsStore.autoplayNext.toggle() },
                        onPlayNext: { session.playNextNow() },
                        onAddSource: {
                            session.cancelUpNext()
                            showAddNextSourceSheet = true
                        },
                        onDismiss: { session.cancelUpNext() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(CVMotion.spring, value: isFullscreen)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onAppear {
            OrientationController.shared.setAllowedOrientations(.allButUpsideDown)
            session.start()
            scheduleAutoHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hudDismissTask?.cancel()
            session.endSession()
            OrientationController.shared.setAllowedOrientations(.portrait, requestOrientation: .portrait)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                session.handleDidEnterBackground()
            } else if phase == .inactive {
                session.persistProgress()
            }
        }
        .onChange(of: session.engine.isPlaying) { _, playing in
            if playing {
                scheduleAutoHide()
            } else {
                hideControlsTask?.cancel()
                controlsVisible = true
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            PlayerSettingsSheet(session: session, settingsStore: settingsStore, onImportSubtitle: { showSubtitleImporter = true })
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddNextSourceSheet) {
            if let nextEp = session.nextEpisode {
                AddSourceSheet(mediaItem: session.selection.mediaItem, episode: nextEp, sourceManager: sourceManager, httpClient: httpClient) {
                    session.refreshNextEpisodeSource()
                }
            }
        }
        .fileImporter(isPresented: $showSubtitleImporter, allowedContentTypes: subtitleContentTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { session.importExternalSubtitle(url: url) }
        }
    }

    private func inlineStageHeight(for size: CGSize) -> CGFloat {
        let ratioHeight = size.width * 9.0 / 16.0
        let maxInlineHeight = max(size.height * 0.42, 200)
        return min(max(ratioHeight, 190), maxInlineHeight)
    }

    private var videoStageContainer: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                filteredVideoSurface
                    .ignoresSafeArea(edges: isFullscreen ? .all : [])

                gestureSurface(size: proxy.size)

                SubtitleOverlayView(
                    text: session.subtitleEngine.currentText,
                    style: settingsStore.subtitleStyle,
                    controlsVisible: controlsVisible && !isLocked
                )

                topFloatingBadges

                if let skipIndicatorText {
                    Text(skipIndicatorText)
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .cvGlass(Capsule(style: .continuous))
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }

                if let error = session.engine.errorMessage {
                    errorOverlay(error)
                }

                if controlsVisible {
                    PlayerControlsOverlay(
                        session: session,
                        isFullscreen: isFullscreen,
                        isLocked: isLocked,
                        scalingMode: scalingMode,
                        onSkipIntro: activeSkipIntroAction,
                        onClose: { isFullscreen ? toggleFullscreen() : { session.endSession(); dismiss() }() },
                        onToggleFullscreen: { toggleFullscreen() },
                        onToggleLock: {
                            isLocked.toggle()
                            controlsVisible = true
                            scheduleAutoHide()
                        },
                        onSelectScalingMode: { mode in
                            scalingMode = mode
                            scheduleAutoHide()
                        },
                        onOpenSettings: { showSettingsSheet = true },
                        onImportSubtitle: { showSubtitleImporter = true },
                        onUserInteraction: { scheduleAutoHide() }
                    )
                    .transition(.opacity)
                }
            }
            .clipped()
        }
    }

    @ViewBuilder
    private var filteredVideoSurface: some View {
        if session.picturePreset == .standard {
            activeVideoSurface
        } else {
            activeVideoSurface
                .contrast(session.picturePreset.contrast)
                .saturation(session.picturePreset.saturation)
                .brightness(session.picturePreset.brightness)
        }
    }

    @ViewBuilder
    private var activeVideoSurface: some View {
        if session.engine.usesWebSurface,
           let streamURL = session.engine.activeStreamURL ?? session.selection.source.playbackURL {
            WebMediaPlayerSurface(
                controller: session.engine.webBridge,
                streamURL: streamURL,
                rate: session.engine.playbackRate,
                volume: session.engine.volume,
                scalingMode: scalingMode
            )
        } else {
            PlayerLayerView(
                player: session.engine.player,
                scalingMode: scalingMode,
                presentationSize: session.engine.presentationSize
            ) { playerLayer in
                session.pipController.attach(to: playerLayer)
            }
        }
    }

    @ViewBuilder
    private var topFloatingBadges: some View {
        VStack {
            if isHoldBoostingSpeed {
                Label("2.0x Speed", systemImage: "forward.fill")
                    .font(CVFont.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .cvGlass(Capsule(style: .continuous))
                    .padding(.top, CVSpacing.sm)
            } else if let hud = gestureHUD {
                HStack(spacing: 8) {
                    Image(systemName: hud.symbol)
                        .foregroundStyle(CVColor.amber)
                    Text(hud.title)
                        .font(CVFont.micro.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    ProgressView(value: min(max(hud.fraction, 0), 1))
                        .tint(CVColor.iris)
                        .frame(width: 72)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .cvGlass(Capsule(style: .continuous))
                .padding(.top, CVSpacing.sm)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var activeSkipIntroAction: (() -> Void)? {
        guard let ep = session.selection.episode,
              let start = ep.introStartSeconds,
              let end = ep.introEndSeconds,
              end > start,
              session.engine.currentTime >= start,
              session.engine.currentTime < end - 1 else {
            return nil
        }
        return {
            session.engine.seek(to: end, exact: true)
            showSkipFeedback("Skipped Intro")
        }
    }

    private func toggleFullscreen() {
        let nextFullscreen = !isFullscreen
        withAnimation(CVMotion.spring) {
            isFullscreen = nextFullscreen
            if !nextFullscreen && scalingMode == .fill {
                scalingMode = .fit
            }
            controlsVisible = true
        }
        if nextFullscreen {
            OrientationController.shared.setAllowedOrientations(.allButUpsideDown, requestOrientation: .landscapeRight)
        } else {
            OrientationController.shared.setAllowedOrientations(.allButUpsideDown, requestOrientation: .portrait)
        }
        scheduleAutoHide()
    }

    private func gestureSurface(size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                guard !isLocked else { return }
                let third = size.width / 3.0
                if location.x < third {
                    Haptics.impact(.light)
                    session.engine.skip(by: -10)
                    showSkipFeedback("-10s")
                } else if location.x > third * 2.0 {
                    Haptics.impact(.light)
                    session.engine.skip(by: 10)
                    showSkipFeedback("+10s")
                } else {
                    session.engine.togglePlayPause()
                }
                scheduleAutoHide()
            }
            .onTapGesture(count: 1) {
                withAnimation(CVMotion.gentle) {
                    controlsVisible.toggle()
                }
                if controlsVisible { scheduleAutoHide() }
            }
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 28, pressing: { pressing in
                guard !isLocked else { return }
                if !pressing && isHoldBoostingSpeed {
                    session.engine.setRate(preHoldRate)
                    withAnimation(CVMotion.snappy) { isHoldBoostingSpeed = false }
                }
            }, perform: {
                guard !isLocked, !isHoldBoostingSpeed else { return }
                Haptics.impact(.medium)
                preHoldRate = session.engine.playbackRate
                session.engine.setRate(2.0)
                withAnimation(CVMotion.snappy) { isHoldBoostingSpeed = true }
            })
            .gesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onChanged { value in
                        handleDragChanged(value, in: size)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        guard !isLocked, size.height > 40, size.width > 80 else { return }
        if activeDragMode == nil {
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            if dx > dy * 1.35 {
                activeDragMode = .horizontalSeek(initialTime: session.engine.currentTime)
                session.engine.isSeeking = true
            } else if value.startLocation.x < size.width * 0.5 {
                activeDragMode = .brightness(initial: currentScreenBrightness)
            } else {
                activeDragMode = .volume(initial: session.engine.volume)
            }
        }

        switch activeDragMode {
        case .brightness(let initial):
            let delta = -value.translation.height / max(size.height * 0.8, 160)
            let updated = min(max(initial + delta, 0.02), 1.0)
            setScreenBrightness(updated)
            presentHUD(symbol: "sun.max.fill", title: "\(Int((updated * 100).rounded()))%", fraction: Double(updated))
        case .volume(let initial):
            let delta = Float(-value.translation.height / max(size.height * 0.8, 160))
            let updated = min(max(initial + delta, 0), 1.0)
            session.engine.setVolume(updated)
            let icon = updated < 0.02 ? "speaker.slash.fill" : "speaker.wave.3.fill"
            presentHUD(symbol: icon, title: "\(Int((updated * 100).rounded()))%", fraction: Double(updated))
        case .horizontalSeek(let initialTime):
            let maxSpan = min(max(session.engine.duration * 0.25, 60), 180)
            let deltaSec = Double(value.translation.width / max(size.width, 200)) * maxSpan
            let upper = max(session.engine.duration, initialTime)
            let target = min(max(initialTime + deltaSec, 0), upper)
            pendingTouchSeekTarget = target
            let sign = deltaSec >= 0 ? "+" : ""
            skipIndicatorText = "\(target.formattedPlaybackTime) (\(sign)\(Int(deltaSec.rounded()))s)"
        case .none:
            break
        }
    }

    private func handleDragEnded() {
        if let target = pendingTouchSeekTarget {
            session.engine.isSeeking = false
            session.engine.seek(to: target, exact: true)
            pendingTouchSeekTarget = nil
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(CVMotion.gentle) { skipIndicatorText = nil }
            }
        }
        activeDragMode = nil
        hudDismissTask?.cancel()
        hudDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(CVMotion.gentle) { gestureHUD = nil }
        }
    }

    private var currentScreenBrightness: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.brightness ?? 0.65
    }

    private func setScreenBrightness(_ value: CGFloat) {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.brightness = value
    }

    private func presentHUD(symbol: String, title: String, fraction: Double) {
        hudDismissTask?.cancel()
        gestureHUD = (symbol, title, fraction)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: CVSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(CVColor.warning)
            Text("Playback Error")
                .font(CVFont.sectionTitle)
                .foregroundStyle(.white)
            Text(message)
                .font(CVFont.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            HStack(spacing: CVSpacing.sm) {
                Button("Retry") { session.retry() }
                    .buttonStyle(CVPrimaryButtonStyle(compact: true))
                Button("Close") {
                    session.endSession()
                    dismiss()
                }
                .buttonStyle(CVGlassButtonStyle(compact: true))
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private func showSkipFeedback(_ text: String) {
        withAnimation(CVMotion.snappy) { skipIndicatorText = text }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(CVMotion.gentle) { skipIndicatorText = nil }
        }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        guard session.engine.isPlaying && !isLocked else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            if session.engine.isPlaying && !isLocked && !session.engine.isSeeking {
                withAnimation(CVMotion.gentle) { controlsVisible = false }
            }
        }
    }

    private var subtitleContentTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let srt = UTType(filenameExtension: "srt") { types.append(srt) }
        if let vtt = UTType(filenameExtension: "vtt") { types.append(vtt) }
        return types
    }
}
