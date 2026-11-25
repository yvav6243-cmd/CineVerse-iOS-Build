import Foundation
import AVFoundation
import CoreMedia
import Observation

@MainActor
@Observable
public final class PlayerEngine {
    public let player = AVPlayer()
    public let webBridge = WebMediaBridgeController()

    public private(set) var isPlaying: Bool = false
    public private(set) var isBuffering: Bool = false
    public private(set) var isReady: Bool = false
    public private(set) var usesWebSurface: Bool = false
    public private(set) var activeStreamURL: URL?
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

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var loadedRangesObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var endNotificationToken: NSObjectProtocol?
    private var failNotificationToken: NSObjectProtocol?

    public init(subtitleEngine: SubtitleEngine) {
        self.subtitleEngine = subtitleEngine
        configureAudioSession()
        attachPlayerObservers()
        wireWebBridge()
    }

    public func load(selection: PreWatchPlaybackSelection, subtitleStyle: SubtitleAppearanceStyle) {
        currentSelection = selection
        currentSubtitleStyle = subtitleStyle
        errorMessage = nil
        isReady = false
        currentTime = 0
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
            errorMessage = "No playable stream URL available for this selection."
            return
        }

        activateStream(url: streamURL, format: effectiveFormat)
        applyQuality(selection.selectedQuality)
        applySubtitle(selection.selectedSubtitleTrack, style: subtitleStyle)
    }

    public func play() {
        if usesWebSurface {
            webBridge.play()
        } else {
            player.play()
            if playbackRate != 1.0 { player.rate = playbackRate }
        }
        isPlaying = true
    }

    public func pause() {
        if usesWebSurface {
            webBridge.pause()
        } else {
            player.pause()
        }
        isPlaying = false
    }

    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    public func seek(to seconds: TimeInterval, exact: Bool = true) {
        let upper = duration > 0 ? duration : max(seconds, 0)
        let clamped = min(max(seconds, 0), upper)
        currentTime = clamped
        subtitleEngine.update(forTime: clamped)
        if usesWebSurface {
            webBridge.seek(to: clamped)
        } else {
            let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
            let tolerance: CMTime = exact ? .zero : CMTime(seconds: 0.5, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
    }

    public func skip(by delta: TimeInterval) {
        seek(to: currentTime + delta, exact: true)
    }

    public func setRate(_ rate: Float) {
        playbackRate = rate
        if usesWebSurface {
            webBridge.setRate(rate)
        } else if isPlaying {
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
            activateStream(url: variantURL, format: nextFormat)
        }
    }

    public func selectAudio(_ track: AudioTrackOption) {
        selectedAudioTrack = track
        if let altVideoURL = track.alternateMuxedVideoURL, altVideoURL != activeStreamURL {
            pendingStartSeek = currentTime
            activateStream(url: altVideoURL, format: currentSelection?.source.format ?? .mp4)
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
        loadedRangesObservation?.invalidate()
        loadedRangesObservation = nil
        if let endToken = endNotificationToken { NotificationCenter.default.removeObserver(endToken); endNotificationToken = nil }
        if let failToken = failNotificationToken { NotificationCenter.default.removeObserver(failToken); failNotificationToken = nil }
        player.replaceCurrentItem(with: nil)
        subtitleEngine.clear()
    }

    private func resolvePlaybackURL(selection: PreWatchPlaybackSelection, quality: VideoQualityVariant, audio: AudioTrackOption) -> URL? {
        if let alt = audio.alternateMuxedVideoURL { return alt }
        if selection.source.format != .hls, let variantURL = quality.variantStreamURL { return variantURL }
        return selection.source.playbackURL
    }

    private func activateStream(url: URL, format: VideoStreamFormat) {
        activeStreamURL = url
        if format.usesWebMediaSurface {
            player.pause()
            player.replaceCurrentItem(with: nil)
            usesWebSurface = true
            isBuffering = true
            cachedCodecName = format == .webm ? "VP9" : "DASH"
            isPlaying = true
            webBridge.loadStream(url: url, startTime: pendingStartSeek, rate: playbackRate, volume: volume, aspectFill: false)
        } else {
            webBridge.teardown()
            usesWebSurface = false
            replaceAVPlayerItem(with: url)
        }
    }

    private func wireWebBridge() {
        webBridge.onReady = { [weak self] dur, w, h in
            guard let self else { return }
            self.isReady = true
            self.isBuffering = false
            if dur > 0 { self.duration = dur }
            if w > 0 && h > 0 {
                self.diagnostics = PlaybackQualityDiagnostics(
                    videoWidth: w,
                    videoHeight: h,
                    observedBitrateBitsPerSecond: 0,
                    framesPerSecond: 24,
                    dynamicRange: "SDR",
                    videoCodec: self.cachedCodecName ?? "VP9"
                )
            }
        }
        webBridge.onTimeUpdate = { [weak self] cur, buf, paused in
            guard let self, self.usesWebSurface, !self.isSeeking else { return }
            self.currentTime = cur
            self.bufferedTime = max(buf, cur)
            self.isPlaying = !paused
            self.isBuffering = false
            self.subtitleEngine.update(forTime: cur)
            self.onTimeUpdate?(cur, self.duration)
        }
        webBridge.onEnded = { [weak self] in
            guard let self, self.usesWebSurface else { return }
            self.isPlaying = false
            self.onPlaybackEnded?()
        }
        webBridge.onError = { [weak self] msg in
            guard let self, self.usesWebSurface else { return }
            self.errorMessage = msg
            self.isPlaying = false
            self.onPlaybackFailed?(msg)
        }
    }

    private func replaceAVPlayerItem(with url: URL) {
        statusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
        if let endToken = endNotificationToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken = failNotificationToken { NotificationCenter.default.removeObserver(failToken) }

        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = volume
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12
        if currentSelection?.source.format == .hls, let initialTier = selectedQuality?.tier {
            item.preferredMaximumResolution = initialTier.preferredMaximumResolution
            item.preferredPeakBitRate = initialTier.preferredPeakBitRate
        }

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in self?.handleItemStatusChange(playerItem) }
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
                self?.isPlaying = false
                self?.onPlaybackEnded?()
            }
        }
        failNotificationToken = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                let msg = err?.localizedDescription ?? "Playback failed."
                self?.errorMessage = msg
                self?.isPlaying = false
                self?.onPlaybackFailed?(msg)
            }
        }

        player.replaceCurrentItem(with: item)
        play()
    }

    private func handleItemStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            isReady = true
            let rawDuration = CMTimeGetSeconds(item.duration)
            if rawDuration.isFinite && rawDuration > 0 { duration = rawDuration }
            if pendingStartSeek > 1 {
                let target = pendingStartSeek
                pendingStartSeek = 0
                seek(to: target, exact: true)
            }
            if let audio = selectedAudioTrack { selectAudio(audio) }
            if let sub = selectedSubtitleTrack, sub.format == .embeddedHLS { selectEmbeddedLegible(sub, style: currentSubtitleStyle) }
            Task { @MainActor [weak self] in
                await self?.probeVideoTrackMetadata(from: item.asset)
            }
        case .failed:
            let msg = item.error?.localizedDescription ?? "Unable to load media stream."
            errorMessage = msg
            isPlaying = false
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
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] avPlayer, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.usesWebSurface else { return }
                switch avPlayer.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate: self.isBuffering = true
                case .playing: self.isBuffering = false; self.isPlaying = true
                case .paused: self.isBuffering = false; self.isPlaying = false
                @unknown default: break
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
