import Foundation
import UIKit
import Observation

@MainActor
@Observable
public final class PlayerSession {
    public private(set) var selection: PreWatchPlaybackSelection
    public let engine: PlayerEngine
    public let subtitleEngine: SubtitleEngine
    public let pipController = PictureInPictureController()

    public private(set) var showUpNextOverlay: Bool = false
    public private(set) var upNextCountdown: Int = 5
    public private(set) var nextEpisode: MediaEpisode?
    public private(set) var nextSelection: PreWatchPlaybackSelection?
    public private(set) var alternativeSources: [VideoSourceDescriptor] = []
    public private(set) var isSwitchingSource: Bool = false
    public var picturePreset: VideoPicturePreset = {
        if let raw = UserDefaults.standard.string(forKey: "cv_picture_preset"),
           let saved = VideoPicturePreset(rawValue: raw) {
            return saved
        }
        return .vividCinema
    }() {
        didSet {
            UserDefaults.standard.set(picturePreset.rawValue, forKey: "cv_picture_preset")
        }
    }

    private var failedSourceIDs: Set<String> = []

    private let progressRepository: ProgressRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private let trackerService: TrackerService
    private let sourceManager: VideoSourceManager
    private let settingsStore: SettingsStore
    private let nowPlaying = NowPlayingController()
    private let liveActivity = PlaybackActivityController()

    private var lastSavedAt: Date = .distantPast
    private var hasMarkedWatchedCurrent: Bool = false
    private var hasEvaluatedUpNext: Bool = false
    private var upNextTask: Task<Void, Never>?
    private var cachedArtwork: UIImage?

    public init(
        selection: PreWatchPlaybackSelection,
        httpClient: HTTPClient,
        progressRepository: ProgressRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol,
        trackerService: TrackerService,
        sourceManager: VideoSourceManager,
        settingsStore: SettingsStore
    ) {
        self.selection = selection
        self.subtitleEngine = SubtitleEngine(httpClient: httpClient)
        self.engine = PlayerEngine(subtitleEngine: subtitleEngine)
        self.progressRepository = progressRepository
        self.libraryRepository = libraryRepository
        self.trackerService = trackerService
        self.sourceManager = sourceManager
        self.settingsStore = settingsStore

        wireEngineCallbacks()
    }

    public func start() {
        loadSelection(selection)
        configureRemoteCommands()
        let currentItem = selection.mediaItem
        let currentEp = selection.episode
        Task {
            alternativeSources = await sourceManager
                .resolveSources(for: currentItem, episode: currentEp)
                .filter { $0.isAvailable && $0.format.isDirectlyPlayable }
        }
        Task {
            if let posterURL = selection.mediaItem.posterURL {
                cachedArtwork = await ImagePipeline.shared.image(
                    for: posterURL,
                    targetSize: CGSize(width: 300, height: 450),
                    scale: 2
                )
            }
        }
    }

    public func switchSource(to source: VideoSourceDescriptor) async {
        guard source.id != selection.source.id else { return }
        isSwitchingSource = true
        defer { isSwitchingSource = false }

        let inspected = await sourceManager.inspect(
            source,
            originalLanguage: selection.mediaItem.originalLanguage
        )

        let preferredTier = engine.selectedQuality?.tier
        let nextQuality = inspected.availableQualities.first(where: { $0.tier == preferredTier })
            ?? inspected.availableQualities.first
            ?? VideoQualityVariant(id: "auto", tier: .auto, variantStreamURL: inspected.playbackURL)

        let preferredAudioLang = engine.selectedAudioTrack?.languageCode.lowercased()
        let nextAudio = inspected.availableAudioTracks.first(where: { $0.languageCode.lowercased() == preferredAudioLang })
            ?? inspected.availableAudioTracks.first
            ?? selection.selectedAudioTrack

        let nextSubtitle: SubtitleTrackOption?
        if let currentSubLang = engine.selectedSubtitleTrack?.languageCode.lowercased() {
            nextSubtitle = inspected.availableSubtitles.first(where: { $0.languageCode.lowercased() == currentSubLang })
        } else {
            nextSubtitle = nil
        }

        let openPrefix = "openstream:\(selection.mediaItem.id):"
        let keepPosition = !OpenCinemaLibrary.streams(forItemID: selection.mediaItem.id).isEmpty
            && selection.source.id.hasPrefix(openPrefix)
            && source.id.hasPrefix(openPrefix)

        let updatedSelection = PreWatchPlaybackSelection(
            mediaItem: selection.mediaItem,
            episode: selection.episode,
            source: inspected,
            selectedQuality: nextQuality,
            selectedAudioTrack: nextAudio,
            selectedSubtitleTrack: nextSubtitle,
            startPositionSeconds: keepPosition ? engine.currentTime : 0
        )

        persistProgress(force: true)
        loadSelection(updatedSelection)
        engine.play()
    }

    public func selectQuality(_ quality: VideoQualityVariant) {
        engine.applyQuality(quality)
        savePlaybackPreferences()
    }

    public func selectAudio(_ track: AudioTrackOption) {
        engine.selectAudio(track)
        savePlaybackPreferences()
    }

    public func selectSubtitle(_ track: SubtitleTrackOption?) {
        engine.applySubtitle(track, style: settingsStore.subtitleStyle)
        savePlaybackPreferences()
    }

    public func importExternalSubtitle(url: URL) {
        let ext = url.pathExtension.lowercased()
        let format: SubtitleFormat = ext == "vtt" ? .webVTT : .srt
        guard let imported = try? LocalVideoStore.shared.importSubtitle(from: url) else { return }
        let localURL = LocalVideoStore.shared.resolveURL(forRelativePath: imported.relativePath)
        let track = SubtitleTrackOption(
            id: "imported-\(UUID().uuidString)",
            languageCode: settingsStore.defaultSubtitleLanguage == "off" ? "en" : settingsStore.defaultSubtitleLanguage,
            displayName: imported.fileName,
            format: format,
            externalURL: localURL
        )
        engine.addCustomSubtitleTrack(track)
    }

    public func refreshNextEpisodeSource() {
        guard let nextEpisode else { return }
        Task {
            nextSelection = await sourceManager.nextEpisodeSelection(after: selection, nextEpisode: nextEpisode)
        }
    }

    public func playNextNow() {
        upNextTask?.cancel()
        showUpNextOverlay = false
        guard let nextSelection else { return }
        persistProgress(force: true)
        loadSelection(nextSelection)
    }

    public func cancelUpNext() {
        upNextTask?.cancel()
        showUpNextOverlay = false
    }

    public func persistProgress(force: Bool = false) {
        guard force || settingsStore.autosaveProgress else { return }
        let seasonNum = selection.episode?.seasonNumber ?? 0
        let episodeNum = selection.episode?.episodeNumber ?? 0
        let episodeTitle = selection.episode?.title ?? selection.mediaItem.localizedTitle

        _ = progressRepository.savePlaybackPosition(
            item: selection.mediaItem,
            season: seasonNum,
            episode: episodeNum,
            episodeTitle: episodeTitle,
            positionSeconds: engine.currentTime,
            durationSeconds: engine.duration,
            sourceID: selection.source.id
        )
        lastSavedAt = Date()
    }

    public func endSession() {
        upNextTask?.cancel()
        persistProgress(force: true)
        engine.teardown()
        pipController.detach()
        nowPlaying.clearRemoteCommands()
        liveActivity.end()
    }

    private func loadSelection(_ newSelection: PreWatchPlaybackSelection) {
        selection = newSelection
        hasMarkedWatchedCurrent = false
        hasEvaluatedUpNext = false
        showUpNextOverlay = false
        upNextTask?.cancel()

        nextEpisode = trackerService.nextEpisode(after: newSelection.episode, in: newSelection.mediaItem)
        nextSelection = nil

        engine.load(selection: newSelection, subtitleStyle: settingsStore.subtitleStyle)
        savePlaybackPreferences()

        liveActivity.start(
            title: newSelection.mediaItem.localizedTitle,
            episodeCode: newSelection.episode?.formattedCode,
            symbolName: newSelection.mediaItem.projectType.symbolName,
            elapsed: newSelection.startPositionSeconds,
            duration: Double(max(newSelection.episode?.durationMinutes ?? newSelection.mediaItem.durationMinutes, 1) * 60)
        )
    }

    private func wireEngineCallbacks() {
        engine.onTimeUpdate = { [weak self] currentTime, duration in
            guard let self else { return }
            let now = Date()
            if self.settingsStore.autosaveProgress && now.timeIntervalSince(self.lastSavedAt) >= 10 {
                self.persistProgress()
            }

            if duration > 10 {
                let fraction = currentTime / duration
                if fraction >= 0.90 && !self.hasMarkedWatchedCurrent {
                    self.hasMarkedWatchedCurrent = true
                    self.markCurrentAsWatched(durationSeconds: duration)
                }
                if fraction >= 0.96 && !self.hasEvaluatedUpNext && self.nextEpisode != nil {
                    self.hasEvaluatedUpNext = true
                    self.prepareUpNext()
                }
            }

            self.nowPlaying.updateMetadata(
                title: self.selection.mediaItem.localizedTitle,
                subtitle: self.selection.episode?.formattedCode,
                artwork: self.cachedArtwork,
                elapsed: currentTime,
                duration: duration,
                rate: self.engine.playbackRate,
                isPlaying: self.engine.isPlaying
            )
            self.liveActivity.update(
                isPlaying: self.engine.isPlaying,
                elapsed: currentTime,
                duration: duration
            )
        }

        engine.onPlaybackEnded = { [weak self] in
            guard let self else { return }
            self.persistProgress(force: true)
            if !self.hasMarkedWatchedCurrent {
                self.hasMarkedWatchedCurrent = true
                self.markCurrentAsWatched(durationSeconds: self.engine.duration)
            }
            if !self.hasEvaluatedUpNext && self.nextEpisode != nil {
                self.hasEvaluatedUpNext = true
                self.prepareUpNext()
            }
        }

        engine.onPlaybackFailed = { [weak self] _ in
            guard let self else { return }
            let failedID = self.selection.source.id
            self.failedSourceIDs.insert(failedID)
            if let fallback = SourceFailoverPlanner.nextFallbackSource(
                afterFailedID: failedID,
                triedIDs: self.failedSourceIDs,
                candidates: self.alternativeSources
            ) {
                Task { @MainActor [weak self] in
                    await self?.switchSource(to: fallback)
                }
            }
        }
    }

    private func markCurrentAsWatched(durationSeconds: TimeInterval) {
        let seasonNum = selection.episode?.seasonNumber ?? 0
        let epNum = selection.episode?.episodeNumber ?? 0
        let epTitle = selection.episode?.title ?? selection.mediaItem.localizedTitle
        let minutes = max(Int((durationSeconds / 60.0).rounded()), selection.episode?.durationMinutes ?? selection.mediaItem.durationMinutes, 1)

        trackerService.markEpisodeWatched(
            item: selection.mediaItem,
            season: seasonNum,
            episode: epNum,
            episodeTitle: epTitle,
            durationMinutes: minutes,
            watched: true
        )
    }

    private func prepareUpNext() {
        guard let nextEpisode else { return }
        Task {
            let resolved = await sourceManager.nextEpisodeSelection(after: selection, nextEpisode: nextEpisode)
            nextSelection = resolved
            showUpNextOverlay = true

            guard resolved != nil && settingsStore.autoplayNext else { return }
            upNextCountdown = 5
            upNextTask?.cancel()
            upNextTask = Task { [weak self] in
                for tick in stride(from: 5, through: 1, by: -1) {
                    guard let self, !Task.isCancelled else { return }
                    self.upNextCountdown = tick
                    try? await Task.sleep(for: .seconds(1))
                }
                guard let self, !Task.isCancelled else { return }
                self.playNextNow()
            }
        }
    }

    private func configureRemoteCommands() {
        nowPlaying.configureRemoteCommands(
            onPlay: { [weak self] in self?.engine.play() },
            onPause: { [weak self] in
                self?.engine.pause()
                self?.persistProgress()
            },
            onToggle: { [weak self] in self?.engine.togglePlayPause() },
            onSkipForward: { [weak self] delta in self?.engine.skip(by: delta) },
            onSkipBackward: { [weak self] delta in self?.engine.skip(by: -delta) },
            onSeek: { [weak self] target in self?.engine.seek(to: target, exact: true) }
        )
    }

    private func savePlaybackPreferences() {
        _ = libraryRepository.upsert(from: selection.mediaItem)
        libraryRepository.savePlaybackPreferences(
            mediaID: selection.mediaItem.id,
            sourceID: selection.source.id,
            audioLang: engine.selectedAudioTrack?.languageCode,
            subtitleLang: engine.selectedSubtitleTrack?.languageCode ?? "off",
            quality: engine.selectedQuality?.tier
        )
    }
}
