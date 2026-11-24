import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

public struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: PlayerSession
    @State private var controlsVisible: Bool = true
    @State private var isLocked: Bool = false
    @State private var isAspectFill: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showSubtitleImporter: Bool = false
    @State private var showAddNextSourceSheet: Bool = false
    @State private var skipIndicatorText: String? = nil
    @State private var hideControlsTask: Task<Void, Never>?

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
            selection: selection,
            httpClient: httpClient,
            progressRepository: progressRepository,
            libraryRepository: libraryRepository,
            trackerService: trackerService,
            sourceManager: sourceManager,
            settingsStore: settingsStore
        ))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                PlayerLayerView(
                    player: session.engine.player,
                    videoGravity: isAspectFill ? .resizeAspectFill : .resizeAspect
                ) { playerLayer in
                    session.pipController.attach(to: playerLayer)
                }
                .ignoresSafeArea()

                gestureSurface(size: proxy.size)

                SubtitleOverlayView(
                    text: session.subtitleEngine.currentText,
                    style: settingsStore.subtitleStyle,
                    controlsVisible: controlsVisible && !isLocked
                )

                if let skipIndicatorText {
                    Text(skipIndicatorText)
                        .font(CVFont.sectionTitle)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .cvGlass(Capsule(style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                }

                if let error = session.engine.errorMessage {
                    errorOverlay(error)
                }

                if controlsVisible {
                    PlayerControlsOverlay(
                        session: session,
                        isLocked: isLocked,
                        isAspectFill: isAspectFill,
                        onClose: {
                            session.endSession()
                            dismiss()
                        },
                        onToggleLock: {
                            isLocked.toggle()
                            controlsVisible = true
                            scheduleAutoHide()
                        },
                        onToggleAspectFill: {
                            isAspectFill.toggle()
                            scheduleAutoHide()
                        },
                        onOpenSettings: {
                            showSettingsSheet = true
                        },
                        onImportSubtitle: {
                            showSubtitleImporter = true
                        },
                        onUserInteraction: {
                            scheduleAutoHide()
                        }
                    )
                    .transition(.opacity)
                }

                if session.showUpNextOverlay, let nextEp = session.nextEpisode {
                    UpNextOverlay(
                        nextEpisode: nextEp,
                        hasPlayableSource: session.nextSelection != nil,
                        countdownSeconds: session.upNextCountdown,
                        autoplayEnabled: settingsStore.autoplayNext,
                        onPlayNext: {
                            session.playNextNow()
                        },
                        onAddSource: {
                            session.cancelUpNext()
                            showAddNextSourceSheet = true
                        },
                        onDismiss: {
                            session.cancelUpNext()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            OrientationController.shared.setAllowedOrientations(.allButUpsideDown)
            session.start()
            scheduleAutoHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            session.endSession()
            OrientationController.shared.setAllowedOrientations(.portrait, requestOrientation: .portrait)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                session.persistProgress()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            PlayerSettingsSheet(
                session: session,
                settingsStore: settingsStore,
                onImportSubtitle: {
                    showSubtitleImporter = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddNextSourceSheet) {
            if let nextEp = session.nextEpisode {
                AddSourceSheet(
                    mediaItem: session.selection.mediaItem,
                    episode: nextEp,
                    sourceManager: sourceManager,
                    httpClient: httpClient,
                    onAdded: {
                        session.refreshNextEpisodeSource()
                    }
                )
            }
        }
        .fileImporter(
            isPresented: $showSubtitleImporter,
            allowedContentTypes: subtitleContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                session.importExternalSubtitle(url: url)
            }
        }
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
                if controlsVisible {
                    scheduleAutoHide()
                }
            }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: CVSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(CVColor.warning)
            Text("Playback Error")
                .font(CVFont.sectionTitle)
                .foregroundStyle(.white)
            Text(message)
                .font(CVFont.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HStack(spacing: CVSpacing.sm) {
                Button("Retry") {
                    session.start()
                }
                .buttonStyle(CVPrimaryButtonStyle(compact: true))
                Button("Close") {
                    session.endSession()
                    dismiss()
                }
                .buttonStyle(CVGlassButtonStyle(compact: true))
            }
        }
        .padding(CVSpacing.lg)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private func showSkipFeedback(_ text: String) {
        withAnimation(CVMotion.snappy) {
            skipIndicatorText = text
        }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(CVMotion.gentle) {
                skipIndicatorText = nil
            }
        }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        guard session.engine.isPlaying || !isLocked else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            if session.engine.isPlaying && !isLocked {
                withAnimation(CVMotion.gentle) {
                    controlsVisible = false
                }
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
