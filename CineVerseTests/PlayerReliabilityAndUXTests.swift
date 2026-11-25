import Foundation
import AVFoundation
import CoreGraphics
import SwiftData
import Testing
@testable import CineVerse

private struct StubPRITunesService: ITunesCatalogServiceProtocol {
    func topMovies(genreID: Int?, limit: Int) async throws -> [MediaItem] { [] }
    func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem] { [] }
    func searchMovies(query: String, limit: Int) async throws -> [MediaItem] { [] }
    func lookupDetails(providerID: String) async throws -> MediaItem? { nil }
    func findPlayablePreviews(title: String, originalTitle: String, isEpisodic: Bool, seasonNumber: Int?, episodeNumber: Int?, limit: Int) async -> [ITunesPreviewMatch] { [] }
    func findPlayablePreviewURL(title: String, originalTitle: String, isEpisodic: Bool, episodeNumber: Int?) async -> URL? { nil }
    func openCinemaShowcase() -> [MediaItem] { OpenCinemaLibrary.items }
    func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)? { nil }
}

private struct StubPRArchiveService: InternetArchiveServiceProtocol {
    func findPlayableMatch(title: String, originalTitle: String, year: Int, originalLanguage: String) async throws -> InternetArchiveVideoMatch? { nil }
}

private struct StubPRWikimediaService: WikimediaCinemaServiceProtocol {
    func resolveByFileTitle(_ fileTitle: String, originalLanguage: String) async throws -> WikimediaVideoMatch? { nil }
    func findFullLengthMatch(title: String, originalTitle: String, year: Int, expectedDurationMinutes: Int, isEpisodic: Bool, episodeTitle: String?, originalLanguage: String) async throws -> WikimediaVideoMatch? { nil }
}

@MainActor
private func makeTestSelection(
    itemID: String = "opencinema:movie:test-hls",
    format: VideoStreamFormat = .hls,
    urlString: String = "https://test.example.invalid/stream/master.m3u8",
    startPositionSeconds: TimeInterval = 0
) -> PreWatchPlaybackSelection {
    let audioEN = AudioTrackOption(id: "audio-en", languageCode: "en", displayName: "English", voiceoverStudio: "Original Mix", isOriginal: true, isDefault: true)
    let audioES = AudioTrackOption(id: "audio-es", languageCode: "es", displayName: "Spanish", voiceoverStudio: "Spanish Dub", isOriginal: false)
    let qAuto = VideoQualityVariant(id: "auto", tier: .auto, variantStreamURL: URL(string: urlString))
    let q1080 = VideoQualityVariant(id: "1080", tier: .p1080, bandwidthBitsPerSecond: 6_000_000, width: 1920, height: 1080, variantStreamURL: URL(string: urlString))
    let q720 = VideoQualityVariant(id: "720", tier: .p720, bandwidthBitsPerSecond: 3_000_000, width: 1280, height: 720, variantStreamURL: URL(string: urlString))

    let source = VideoSourceDescriptor(
        id: "src-\(itemID)",
        providerID: "open_stream",
        providerName: "CineVerse Native HLS",
        sourceDescription: "Verified stream",
        isAvailable: true,
        format: format,
        playbackURL: URL(string: urlString),
        availableQualities: [qAuto, q1080, q720],
        availableAudioTracks: [audioEN, audioES],
        durationSeconds: 600,
        healthStatus: .online(latencyMs: 30)
    )
    let item = MediaItem(
        id: itemID,
        primarySource: .openCinema,
        projectType: .movie,
        localizedTitle: "Test Feature",
        originalTitle: "Test Feature",
        synopsis: "Synopsis",
        releaseYear: 2024,
        countryOfOrigin: "US",
        originalLanguage: "en",
        genres: ["Sci-Fi"],
        durationMinutes: 10,
        ratings: MultiSourceRatings(tmdbScore: 8.5)
    )
    return PreWatchPlaybackSelection(
        mediaItem: item,
        episode: nil,
        source: source,
        selectedQuality: qAuto,
        selectedAudioTrack: audioEN,
        selectedSubtitleTrack: nil,
        startPositionSeconds: startPositionSeconds
    )
}

@Suite("Category 12: Mandatory Player Reliability, Scaling, Quality & Ergonomic UX Tests (TEST 1–10)")
struct PlayerReliabilityAndUXTests {
    @MainActor
    @Test func test01_playThenPauseImmediatelyStopsAVPlayerAndSyncsState() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        let selection = makeTestSelection()
        engine.load(selection: selection, subtitleStyle: SubtitleAppearanceStyle(), autoPlay: true)
        #expect(engine.isPlaying == true)
        #expect(engine.playbackState.isActivePlaybackIntent == true)

        engine.pause()
        #expect(engine.isPlaying == false)
        #expect(engine.isBuffering == false)
        #expect(engine.playbackState == .paused)
        #expect(engine.player.rate == 0)
        #expect(engine.player.timeControlStatus == .paused)

        // Repeated toggle cycles must stay deterministic and never desync
        engine.togglePlayPause()
        #expect(engine.isPlaying == true)
        engine.togglePlayPause()
        #expect(engine.isPlaying == false)
        #expect(engine.playbackState == .paused)
        #expect(engine.player.rate == 0)
    }

    @MainActor
    @Test func test02_resumeAfterPauseContinuesFromSamePosition() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        engine.load(selection: makeTestSelection(), subtitleStyle: SubtitleAppearanceStyle(), autoPlay: true)
        engine.seek(to: 142.5, exact: true)
        engine.pause()

        let pausedAt = engine.currentTime
        #expect(abs(pausedAt - 142.5) < 0.1)
        #expect(engine.isPlaying == false)
        #expect(engine.playbackState == .paused)

        engine.play()
        #expect(engine.isPlaying == true)
        #expect(abs(engine.currentTime - pausedAt) < 0.1)
    }

    @MainActor
    @Test func test03_pauseThenSeekThenPlayPreservesSeekedPositionWithoutAutoResuming() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        engine.load(selection: makeTestSelection(), subtitleStyle: SubtitleAppearanceStyle(), autoPlay: true)
        engine.pause()
        #expect(engine.isPlaying == false)

        engine.seek(to: 310, exact: true)
        // Seeking while paused MUST NOT auto-resume playback
        #expect(engine.isPlaying == false)
        #expect(engine.playbackState == .paused)
        #expect(engine.player.rate == 0)
        #expect(abs(engine.currentTime - 310) < 0.1)

        engine.play()
        #expect(engine.isPlaying == true)
        #expect(abs(engine.currentTime - 310) < 0.1)
    }

    @Test func test04_videoScalingModesFitFillOriginalPreserveAspectRatioWithoutDistortion() {
        let containerPortrait = CGSize(width: 390, height: 220)
        let landscape16x9 = CGSize(width: 1920, height: 1080)
        let ultrawide = CGSize(width: 2560, height: 1080)

        let fitRect = VideoScalingCalculator.targetFrame(
            containerSize: containerPortrait,
            videoSize: ultrawide,
            displayScale: 3.0,
            mode: .fit
        )
        #expect(fitRect.width <= containerPortrait.width + 0.01)
        #expect(fitRect.height <= containerPortrait.height + 0.01)
        let aspectExpected = ultrawide.width / ultrawide.height
        let aspectActual = fitRect.width / max(fitRect.height, 0.001)
        #expect(abs(aspectActual - aspectExpected) < 0.01)

        let fillRect = VideoScalingCalculator.targetFrame(
            containerSize: containerPortrait,
            videoSize: ultrawide,
            displayScale: 3.0,
            mode: .fill
        )
        #expect(fillRect == CGRect(origin: .zero, size: containerPortrait))

        // 720p stream on a 3x iPhone display (240x135 pt or small 480x270 source): must never upscale beyond native or overflow container
        let smallVideo = CGSize(width: 640, height: 360)
        let originalRect = VideoScalingCalculator.targetFrame(
            containerSize: CGSize(width: 844, height: 390),
            videoSize: smallVideo,
            displayScale: 2.0,
            mode: .original
        )
        #expect(abs(originalRect.width - 320) < 0.5)
        #expect(abs(originalRect.height - 180) < 0.5)
        #expect(abs((originalRect.width / originalRect.height) - (landscape16x9.width / landscape16x9.height)) < 0.02)

        #expect(VideoScalingMode.fit.next == .fill)
        #expect(VideoScalingMode.fill.next == .original)
        #expect(VideoScalingMode.original.next == .fit)
    }

    @MainActor
    @Test func test05_qualitySwitchUpdatesSelectionAndReportsHonestResolutionWithoutFaking() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        let selection = makeTestSelection()
        engine.load(selection: selection, subtitleStyle: SubtitleAppearanceStyle(), autoPlay: false)
        let target720 = selection.source.availableQualities.first(where: { $0.tier == .p720 })!
        engine.applyQuality(target720)
        #expect(engine.selectedQuality?.tier == .p720)

        let target1080 = selection.source.availableQualities.first(where: { $0.tier == .p1080 })!
        engine.applyQuality(target1080)
        #expect(engine.selectedQuality?.tier == .p1080)

        // Diagnostics must report real height without inflating 720p to 1080p
        let honest720 = PlaybackQualityDiagnostics(videoWidth: 1280, videoHeight: 720, observedBitrateBitsPerSecond: 3_200_000, videoCodec: "H.264")
        #expect(honest720.resolutionBadge == "720p HD")
        #expect(!honest720.fullTechnicalSummary.contains("1080"))
    }

    @MainActor
    @Test func test06_audioTrackSwitchUpdatesSelectedVoiceover() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        let selection = makeTestSelection()
        engine.load(selection: selection, subtitleStyle: SubtitleAppearanceStyle(), autoPlay: false)
        #expect(engine.selectedAudioTrack?.languageCode == "en")

        let spanish = selection.source.availableAudioTracks.first(where: { $0.languageCode == "es" })!
        engine.selectAudio(spanish)
        #expect(engine.selectedAudioTrack?.languageCode == "es")
        #expect(engine.selectedAudioTrack?.voiceoverStudio == "Spanish Dub")
    }

    @MainActor
    @Test func test07_closingAndReopeningPlayerRestoresSavedPlaybackProgressAndPreventsDuplicateStart() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let progRepo = ProgressRepository(modelContext: container.mainContext, libraryRepository: libRepo)
        let tracker = TrackerService(libraryRepository: libRepo, progressRepository: progRepo)
        let settings = SettingsStore(modelContext: container.mainContext)
        let sourceMgr = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubPRArchiveService(),
            iTunesService: StubPRITunesService(),
            wikimediaService: StubPRWikimediaService()
        )

        let selection = makeTestSelection(itemID: "opencinema:movie:resume-check", startPositionSeconds: 0)
        let session1 = PlayerSession(
            selection: selection,
            httpClient: URLSessionHTTPClient(),
            progressRepository: progRepo,
            libraryRepository: libRepo,
            trackerService: tracker,
            sourceManager: sourceMgr,
            settingsStore: settings
        )
        session1.start()
        session1.engine.seek(to: 185, exact: true)
        // Calling start() a second time while active must NOT wipe current position
        session1.start()
        #expect(abs(session1.engine.currentTime - 185) < 0.5)
        session1.endSession()

        let saved = progRepo.progress(mediaID: selection.mediaItem.id, season: 0, episode: 0)
        let restoredStart = saved?.positionSeconds ?? 0
        #expect(abs(restoredStart - 185) < 1.0)

        let reopenedSelection = makeTestSelection(itemID: "opencinema:movie:resume-check", startPositionSeconds: restoredStart)
        let session2 = PlayerSession(
            selection: reopenedSelection,
            httpClient: URLSessionHTTPClient(),
            progressRepository: progRepo,
            libraryRepository: libRepo,
            trackerService: tracker,
            sourceManager: sourceMgr,
            settingsStore: settings
        )
        session2.start()
        #expect(abs(session2.engine.currentTime - 185) < 1.0)
        #expect(session2.picturePreset == .standard)
        session2.endSession()
    }

    @Test func test08_compactIPhoneLayoutMetricsPreventZoomedCardsAcrossAllScreenSizes() {
        for width: CGFloat in [320, 375, 390, 393, 430] {
            let cols = CVGridLayoutMetrics.columnCount(for: width)
            let cardW = CVGridLayoutMetrics.cardWidth(for: width)
            #expect(cardW >= 96 && cardW <= 160)
            if width >= 375 {
                #expect(cols == 3)
            } else {
                #expect(cols == 2)
            }
        }
    }

    @MainActor
    @Test func test09_playbackFailureTransitionsToFailedStateAndSupportsFailoverAndRetry() {
        let engine = PlayerEngine(subtitleEngine: SubtitleEngine(httpClient: URLSessionHTTPClient()))
        defer { engine.teardown() }

        let emptySource = VideoSourceDescriptor(
            id: "broken",
            providerID: "open_stream",
            providerName: "Broken",
            sourceDescription: "",
            isAvailable: true,
            format: .hls,
            playbackURL: nil
        )
        let base = makeTestSelection()
        let brokenSelection = PreWatchPlaybackSelection(
            mediaItem: base.mediaItem,
            episode: nil,
            source: emptySource,
            selectedQuality: VideoQualityVariant(id: "auto", tier: .auto),
            selectedAudioTrack: base.selectedAudioTrack,
            selectedSubtitleTrack: nil,
            startPositionSeconds: 0
        )

        var failureNotified = false
        engine.onPlaybackFailed = { _ in failureNotified = true }
        engine.load(selection: brokenSelection, subtitleStyle: SubtitleAppearanceStyle(), autoPlay: true)

        #expect(failureNotified == true)
        #expect(engine.playbackState == .failed)
        #expect(engine.isPlaying == false)
        #expect(engine.errorMessage != nil)

        // Recover with healthy stream
        engine.load(selection: base, subtitleStyle: SubtitleAppearanceStyle(), autoPlay: true)
        #expect(engine.errorMessage == nil)
        #expect(engine.playbackState != .failed)
        #expect(engine.isPlaying == true)
    }

    @MainActor
    @Test func test10_builtInPlaybackPrioritizesNativeAVPlayerStreamsOverExternalLinks() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubPRArchiveService(),
            iTunesService: StubPRITunesService(),
            wikimediaService: StubPRWikimediaService()
        )
        let showcaseItem = try #require(OpenCinemaLibrary.items.first { $0.id == "opencinema:movie:open-big-buck-bunny" })
        let sources = await manager.resolveSources(for: showcaseItem, episode: nil)
        #expect(!sources.isEmpty)
        #expect(sources[0].format == .hls)
        #expect(sources[0].format.isDirectlyPlayable == true)
        #expect(sources[0].format.usesWebMediaSurface == false)

        // Top Open Cinema catalog item must be native AVPlayer HLS (not WebM)
        let firstOpen = try #require(OpenCinemaLibrary.films.first)
        #expect(firstOpen.streams.first?.url.pathExtension.lowercased() == "m3u8")
    }
}
