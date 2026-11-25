import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import Observation

@MainActor
@Observable
public final class PlayerEngine {
    public let player = AVPlayer()
    public let webBridge = WebMediaBridgeController()

    public private(set) var playbackState: PlaybackLifecycleState = .loading
    public private(set) var isPlaying: Bool = false
    public private(set) var isBuffering: Bool = false
    public private(set) var isReady: Bool = false
    public private(set) var usesWebSurface: Bool = false
    public private(set) var activeStreamURL: URL?
    public private(set) var presentationSize: CGSize = .zero
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var bufferedTime: TimeInterval = 0
    public private(set) var playbackRate: Float = 1.0
    public private(set) var volume: Float = 1.0
    public private(set) var errorMessage: String?

    public private(set) var availableQualities: [VideoQualityVariant] = []
    public private(set) var availableAudioTracks: [AudioTrackOption] = []
    public private(set) var availableSubtitles: [SubtitleTrackOption] = []
    public private(set) var selectedQuality: VideoQualityVariant?
    public private(set) var selectedAudioTrack: AudioTrackOption?
    public private(set) var selectedSubtitleTrack: SubtitleTrackOption?
    public private(set) var diagnostics: PlaybackQualityDiagnostics = .empty

    public var isSeeking: Bool = false
    public var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?
    public var onPlaybackEnded: (() -> Void)?
    public var onPlaybackFailed: ((String) -> Void)?

    private let subtitleEngine: SubtitleEngine
    private var currentSelection: PreWatchPlaybackSelection?
    private var currentSubtitleStyle = SubtitleAppearanceStyle()
    private var pendingStartSeek: TimeInterval = 0
    private var cachedTrackFPS: Double = 0
    private var cachedDynamicRange: String = "SDR"
    private var cachedCodecName: String?

    private var desiredPlaying: Bool = false
    private var loadGeneration: UInt64 = 0

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var loadedRangesObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var endNotificationToken: NSObjectProtocol?
    private var failNotificationToken: NSObjectProtocol?
    private var interruptionObserverToken: NSObjectProtocol?

    public init(subtitleEngine: SubtitleEngine) {
        self.subtitleEngine = subtitleEngine
        configureAudioSession()
        attachPlayerObservers()
        wireWebBridge()
    }

    public func load(
        selection: PreWatchPlaybackSelection,
        subtitleStyle: SubtitleAppearanceStyle,
        autoPlay: Bool = true
    ) {
        loadGeneration &+= 1
        player.pause()
        webBridge.pause()

        currentSelection = selection
        currentSubtitleStyle = subtitleStyle
        errorMessage = nil
        isReady = false
        desiredPlaying = autoPlay
        isPlaying = autoPlay
        isBuffering = autoPlay
        playbackState = .loading
        presentationSize = .zero
        currentTime = max(0, selection.startPositionSeconds)
        duration = selection.source.durationSeconds ?? 0
        bufferedTime = 0
        diagnostics = .empty
        cachedTrackFPS = 0
        cachedDynamicRange = "SDR"
        cachedCodecName = nil

        availableQualities = selection.source.availableQualities
        availableAudioTracks = selection.source.availableAudioTracks
        availableSubtitles = selection.source.availableSubtitles
        selectedQuality = selection.selectedQuality
        selectedAudioTrack = selection.selectedAudioTrack
        selectedSubtitleTrack = selection.selectedSubtitleTrack
        pendingStartSeek = max(0, selection.startPositionSeconds)

        let effectiveFormat = selection.selectedQuality.variantFormat ?? selection.source.format
        guard let streamURL = resolvePlaybackURL(
            selection: selection,
            quality: selection.selectedQuality,
            audio: selection.selectedAudioTrack
        ) else {
            let msg = "No playable stream URL available for this selection."
            desiredPlaying = false
            isPlaying = false
            isBuffering = false
            playbackState = .failed
            errorMessage = msg
            onPlaybackFailed?(msg)
            return
        }

        activateStream(url: streamURL, format: effectiveFormat, autoPlay: autoPlay)
        applyQuality(selection.selectedQuality)
        applySubtitle(selection.selectedSubtitleTrack, style: subtitleStyle)
    }

    public func play() {
        guard activeStreamURL != nil else { return }
        errorMessage = nil
        desiredPlaying = true
        if usesWebSurface {
            webBridge.setDesiredPlaying(true)
            webBridge.play()
            isPlaying = true
            playbackState = isReady ? (isBuffering ? .buffering : .playing) : .loading
        } else {
            player.defaultRate = playbackRate
            if player.currentItem?.status == .readyToPlay {
                player.playImmediately(atRate: playbackRate)
            } else {
                player.play()
            }
            isPlaying = true
            if player.timeControlStatus == .playing {
                playbackState = .playing
            } else {
                playbackState = isReady ? .buffering : .loading
            }
        }
    }

    public func pause() {
        desiredPlaying = false
        if usesWebSurface {
            webBridge.setDesiredPlaying(false)
            webBridge.pause()
        } else {
            player.pause()
            if player.rate != 0 {
                player.rate = 0
            }
        }
        isPlaying = false
        isBuffering = false
        if errorMessage == nil {
            playbackState = .paused
        }
    }

    public func togglePlayPause() {
        let effectivelyPlaying: Bool
        if usesWebSurface {
            effectivelyPlaying = desiredPlaying || isPlaying
        } else {
            effectivelyPlaying = desiredPlaying || player.timeControlStatus == .playing || player.rate > 0.01
        }
        if effectivelyPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to seconds: TimeInterval, exact: Bool = true) {
        let upper = duration > 0 ? duration : max(seconds, 0)
        let clamped = min(max(seconds, 0), upper)
        currentTime = clamped
        subtitleEngine.update(forTime: clamped)

        let shouldStayPaused = !desiredPlaying
        if usesWebSurface {
            webBridge.seek(to: clamped)
            if shouldStayPaused {
                webBridge.pause()
                isPlaying = false
                if errorMessage == nil { playbackState = .paused }
            }
        } else {
            let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
            let tolerance: CMTime = exact ? .zero : CMTime(seconds: 0.5, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if shouldStayPaused && !self.desiredPlaying {
                        self.player.pause()
                        self.isPlaying = false
                        self.isBuffering = false
                        if self.errorMessage == nil {
                            self.playbackState = .paused
                        }
                    }
                }
            }
        }
    }

    public func skip(by delta: TimeInterval) {
        seek(to: currentTime + delta, exact: true)
    }

    public func setRate(_ rate: Float) {
        playbackRate = rate
        player.defaultRate = rate
        if usesWebSurface {
            webBridge.setRate(rate)
        } else if desiredPlaying && player.timeControlStatus == .playing {
            player.rate = rate
        }
    }

    public func setVolume(_ newVolume: Float) {
        let clamped = min(max(newVolume, 0), 1)
        volume = clamped
        player.volume = clamped
        if usesWebSurface {
            webBridge.setVolume(clamped)
        }
    }

    public func applyQuality(_ variant: VideoQualityVariant) {
        let previousTier = selectedQuality?.tier
        selectedQuality = variant

        if currentSelection?.source.format == .hls, !usesWebSurface {
            guard let item = player.currentItem else { return }
            item.preferredMaximumResolution = variant.tier.preferredMaximumResolution
            item.preferredPeakBitRate = variant.tier.preferredPeakBitRate
            if isReady && PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: previousTier, to: variant.tier) {
                item.preferredForwardBufferDuration = 2
                seek(to: currentTime, exact: false)
                item.preferredForwardBufferDuration = 12
            }
        } else if let variantURL = variant.variantStreamURL, variantURL != activeStreamURL {
            pendingStartSeek = currentTime
            let nextFormat = variant.variantFormat ?? currentSelection?.source.format ?? .mp4
            activateStream(url: variantURL, format: nextFormat, autoPlay: desiredPlaying)
        }
    }

    public func selectAudio(_ track: AudioTrackOption) {
        selectedAudioTrack = track
        if let altVideoURL = track.alternateMuxedVideoURL, altVideoURL != activeStreamURL {
            pendingStartSeek = currentTime
            activateStream(url: altVideoURL, format: currentSelection?.source.format ?? .mp4, autoPlay: desiredPlaying)
            return
        }
        guard !usesWebSurface, let item = player.currentItem else { return }
        Task { @MainActor in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
            if let matchedOption = AVMediaTrackHelpers.matchingOption(in: group, forLanguageCode: track.languageCode, displayName: track.voiceoverStudio) {
                item.select(matchedOption, in: group)
            }
        }
    }

    public func applySubtitle(_ track: SubtitleTrackOption?, style: SubtitleAppearanceStyle) {
        selectedSubtitleTrack = track
        currentSubtitleStyle = style
        guard let track else {
            subtitleEngine.clear()
            deselectEmbeddedLegibleGroup()
            return
        }
        if track.format == .embeddedHLS && !usesWebSurface {
            subtitleEngine.clear()
            selectEmbeddedLegible(track, style: style)
        } else if let url = track.externalURL {
            deselectEmbeddedLegibleGroup()
            Task {
                await subtitleEngine.loadExternal(url: url, format: track.format)
                subtitleEngine.update(forTime: currentTime)
            }
        }
    }

    public func addCustomSubtitleTrack(_ track: SubtitleTrackOption) {
        if !availableSubtitles.contains(where: { $0.id == track.id }) {
            availableSubtitles.append(track)
        }
        applySubtitle(track, style: currentSubtitleStyle)
    }

    public func teardown() {
        loadGeneration &+= 1
        desiredPlaying = false
        isPlaying = false
        isBuffering = false
        playbackState = .paused
        player.pause()
        webBridge.teardown()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        rateObservation?.invalidate()
        rateObservation = nil
        loadedRangesObservation?.invalidate()
        loadedRangesObservation = nil
        if let endToken = endNotificationToken { NotificationCenter.default.removeObserver(endToken); endNotificationToken = nil }
        if let failToken = failNotificationToken { NotificationCenter.default.removeObserver(failToken); failNotificationToken = nil }
        if let intToken = interruptionObserverToken { NotificationCenter.default.removeObserver(intToken); interruptionObserverToken = nil }
        player.replaceCurrentItem(with: nil)
        subtitleEngine.clear()
    }

    private func resolvePlaybackURL(selection: PreWatchPlaybackSelection, quality: VideoQualityVariant, audio: AudioTrackOption) -> URL? {
        if let alt = audio.alternateMuxedVideoURL { return alt }
        if selection.source.format != .hls, let variantURL = quality.variantStreamURL { return variantURL }
        return selection.source.playbackURL
    }

    private func activateStream(url: URL, format: VideoStreamFormat, autoPlay: Bool) {
        activeStreamURL = url
        desiredPlaying = autoPlay
        if format.usesWebMediaSurface {
            player.pause()
            player.replaceCurrentItem(with: nil)
            usesWebSurface = true
            isBuffering = autoPlay
            isPlaying = autoPlay
            playbackState = .loading
            cachedCodecName = format == .webm ? "VP9" : "DASH"
            webBridge.loadStream(
                url: url,
                startTime: pendingStartSeek,
                rate: playbackRate,
                volume: volume,
                scalingMode: .fit,
                autoPlay: autoPlay
            )
        } else {
            webBridge.teardown()
            usesWebSurface = false
            replaceAVPlayerItem(with: url, generation: loadGeneration, autoPlay: autoPlay)
        }
    }

    private func wireWebBridge() {
        webBridge.onReady = { [weak self] dur, w, h in
            guard let self, self.usesWebSurface else { return }
            self.isReady = true
            self.isBuffering = false
            if dur > 0 { self.duration = dur }
            if w > 0 && h > 0 {
                self.presentationSize = CGSize(width: w, height: h)
                self.diagnostics = PlaybackQualityDiagnostics(
                    videoWidth: w,
                    videoHeight: h,
                    observedBitrateBitsPerSecond: 0,
                    framesPerSecond: 24,
                    dynamicRange: "SDR",
                    videoCodec: self.cachedCodecName ?? "VP9"
                )
            }
            if !self.desiredPlaying {
                self.webBridge.pause()
                self.isPlaying = false
                self.playbackState = .ready
            }
        }
        webBridge.onTimeUpdate = { [weak self] cur, buf, paused in
            guard let self, self.usesWebSurface, !self.isSeeking else { return }
            self.currentTime = cur
            self.bufferedTime = max(buf, cur)
            if !self.desiredPlaying {
                if !paused { self.webBridge.pause() }
                self.isPlaying = false
                self.isBuffering = false
                if self.errorMessage == nil { self.playbackState = .paused }
            } else {
                self.isPlaying = !paused
                self.isBuffering = false
                if !paused && self.errorMessage == nil { self.playbackState = .playing }
            }
            self.subtitleEngine.update(forTime: cur)
            self.onTimeUpdate?(cur, self.duration)
        }
        webBridge.onBufferingChanged = { [weak self] active in
            guard let self, self.usesWebSurface else { return }
            guard self.desiredPlaying else {
                self.isBuffering = false
                return
            }
            self.isBuffering = active
            if self.errorMessage == nil {
                self.playbackState = active ? (self.isReady ? .buffering : .loading) : .playing
            }
        }
        webBridge.onPlayStateChanged = { [weak self] playing in
            guard let self, self.usesWebSurface else { return }
            if !self.desiredPlaying {
                if playing { self.webBridge.pause() }
                self.isPlaying = false
                self.isBuffering = false
                if self.errorMessage == nil { self.playbackState = .paused }
            } else {
                self.isPlaying = playing
                if playing { self.playbackState = .playing }
            }
        }
        webBridge.onEnded = { [weak self] in
            guard let self, self.usesWebSurface else { return }
            self.desiredPlaying = false
            self.isPlaying = false
            self.isBuffering = false
            self.playbackState = .paused
            self.onPlaybackEnded?()
        }
        webBridge.onError = { [weak self] msg in
            guard let self, self.usesWebSurface else { return }
            self.desiredPlaying = false
            self.errorMessage = msg
            self.isPlaying = false
            self.isBuffering = false
            self.playbackState = .failed
            self.onPlaybackFailed?(msg)
        }
    }

    private func replaceAVPlayerItem(with url: URL, generation: UInt64, autoPlay: Bool) {
        statusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
        if let endToken = endNotificationToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken = failNotificationToken { NotificationCenter.default.removeObserver(failToken) }

        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = volume
        player.defaultRate = playbackRate

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12
        if currentSelection?.source.format == .hls, let initialTier = selectedQuality?.tier {
            item.preferredMaximumResolution = initialTier.preferredMaximumResolution
            item.preferredPeakBitRate = initialTier.preferredPeakBitRate
        }

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in self?.handleItemStatusChange(playerItem, generation: generation) }
        }
        loadedRangesObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in
                guard let firstRange = playerItem.loadedTimeRanges.first?.timeRangeValue else { return }
                let endSeconds = CMTimeGetSeconds(CMTimeRangeGetEnd(firstRange))
                if endSeconds.isFinite { self?.bufferedTime = endSeconds }
            }
        }
        endNotificationToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.desiredPlaying = false
                self.isPlaying = false
                self.isBuffering = false
                self.playbackState = .paused
                self.onPlaybackEnded?()
            }
        }
        failNotificationToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                guard let self else { return }
                let msg = err?.localizedDescription ?? "Playback failed."
                self.desiredPlaying = false
                self.errorMessage = msg
                self.isPlaying = false
                self.isBuffering = false
                self.playbackState = .failed
                self.onPlaybackFailed?(msg)
            }
        }

        player.replaceCurrentItem(with: item)
        if autoPlay {
            play()
        } else {
            pause()
            playbackState = .loading
        }
    }

    private func handleItemStatusChange(_ item: AVPlayerItem, generation: UInt64) {
        guard generation == loadGeneration else { return }
        switch item.status {
        case .readyToPlay:
            isReady = true
            isBuffering = false
            let rawDuration = CMTimeGetSeconds(item.duration)
            if rawDuration.isFinite && rawDuration > 0 { duration = rawDuration }
            if item.presentationSize.width > 0 && item.presentationSize.height > 0 {
                presentationSize = item.presentationSize
            }
            if pendingStartSeek > 1 {
                let target = pendingStartSeek
                pendingStartSeek = 0
                seek(to: target, exact: true)
            }
            if let audio = selectedAudioTrack { selectAudio(audio) }
            if let sub = selectedSubtitleTrack, sub.format == .embeddedHLS { selectEmbeddedLegible(sub, style: currentSubtitleStyle) }

            if desiredPlaying {
                player.defaultRate = playbackRate
                player.play()
                playbackState = (player.timeControlStatus == .playing) ? .playing : .buffering
            } else {
                player.pause()
                isPlaying = false
                playbackState = .ready
            }

            Task { @MainActor [weak self] in
                await self?.probeVideoTrackMetadata(from: item.asset)
            }
        case .failed:
            let msg = item.error?.localizedDescription ?? "Unable to load media stream."
            desiredPlaying = false
            errorMessage = msg
            isPlaying = false
            isBuffering = false
            playbackState = .failed
            onPlaybackFailed?(msg)
        default:
            break
        }
    }

    private func probeVideoTrackMetadata(from asset: AVAsset) async {
        guard let tracks = try? await asset.loadTracks(withMediaType: .video),
              let first = tracks.first else { return }
        if let fps = try? await first.load(.nominalFrameRate), fps > 0 {
            cachedTrackFPS = Double(fps)
        }
        if let chars = try? await first.load(.mediaCharacteristics) {
            cachedDynamicRange = chars.contains(.containsHDRVideo) ? "HDR" : "SDR"
        }
        if let descs = try? await first.load(.formatDescriptions), let desc = descs.first {
            let subType = CMFormatDescriptionGetMediaSubType(desc)
            cachedCodecName = AVMediaTrackHelpers.codecDisplayName(for: subType)
        }
    }

    private func attachPlayerObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.syncStateFromAVPlayer()
            }
        }
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.syncStateFromAVPlayer()
            }
        }
        interruptionObserverToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = rawType.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            Task { @MainActor [weak self] in
                if type == .began {
                    self?.pause()
                }
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.usesWebSurface, !self.isSeeking else { return }
                let sec = CMTimeGetSeconds(time)
                guard sec.isFinite && sec >= 0 else { return }
                self.currentTime = sec
                if let item = self.player.currentItem {
                    let dur = CMTimeGetSeconds(item.duration)
                    if dur.isFinite && dur > 0 { self.duration = dur }
                    let size = item.presentationSize
                    if size.width > 0 && size.height > 0 {
                        self.presentationSize = size
                    }
                    let lastEvent = item.accessLog()?.events.last
                    let bitrate = max(lastEvent?.observedBitrate ?? 0, lastEvent?.indicatedBitrate ?? 0)
                    let hdrLabel = self.cachedCodecName == "Dolby Vision" ? "Dolby Vision" : self.cachedDynamicRange
                    self.diagnostics = PlaybackQualityDiagnostics(
                        videoWidth: Int(size.width.rounded()),
                        videoHeight: Int(size.height.rounded()),
                        observedBitrateBitsPerSecond: bitrate,
                        framesPerSecond: self.cachedTrackFPS,
                        dynamicRange: hdrLabel,
                        videoCodec: self.cachedCodecName
                    )
                }
                self.subtitleEngine.update(forTime: sec)
                self.onTimeUpdate?(sec, self.duration)
            }
        }
    }

    @MainActor
    private func syncStateFromAVPlayer() {
        guard !usesWebSurface, errorMessage == nil else { return }

        if !desiredPlaying {
            if player.timeControlStatus != .paused || abs(player.rate) > 0.001 {
                player.pause()
                if player.rate != 0 { player.rate = 0 }
            }
            isPlaying = false
            isBuffering = false
            playbackState = .paused
            return
        }

        switch player.timeControlStatus {
        case .playing:
            isPlaying = true
            isBuffering = false
            playbackState = .playing
        case .waitingToPlayAtSpecifiedRate:
            isPlaying = true
            isBuffering = true
            playbackState = isReady ? .buffering : .loading
        case .paused:
            isBuffering = false
            // Never let a stale async `.paused` notification from the previous item flip desiredPlaying back to false while loading/starting.
            if isReady {
                isPlaying = desiredPlaying
                playbackState = desiredPlaying ? .loading : .paused
            }
        @unknown default:
            break
        }
    }

    private func selectEmbeddedLegible(_ track: SubtitleTrackOption, style: SubtitleAppearanceStyle) {
        guard let item = player.currentItem else { return }
        item.textStyleRules = AVMediaTrackHelpers.makeTextStyleRules(from: style)
        Task { @MainActor in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible),
                  let matched = AVMediaTrackHelpers.matchingOption(in: group, forLanguageCode: track.languageCode, displayName: track.displayName) else { return }
            item.select(matched, in: group)
        }
    }

    private func deselectEmbeddedLegibleGroup() {
        guard let item = player.currentItem else { return }
        Task { @MainActor in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
            item.select(nil, in: group)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)
    }
}
