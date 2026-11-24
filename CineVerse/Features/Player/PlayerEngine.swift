import Foundation
import AVFoundation
import CoreMedia
import Observation

@MainActor
@Observable
public final class PlayerEngine {
    public let player = AVPlayer()

    public private(set) var isPlaying: Bool = false
    public private(set) var isBuffering: Bool = false
    public private(set) var isReady: Bool = false
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var bufferedTime: TimeInterval = 0
    public private(set) var playbackRate: Float = 1.0
    public private(set) var errorMessage: String?

    public private(set) var availableQualities: [VideoQualityVariant] = []
    public private(set) var availableAudioTracks: [AudioTrackOption] = []
    public private(set) var availableSubtitles: [SubtitleTrackOption] = []
    public private(set) var selectedQuality: VideoQualityVariant?
    public private(set) var selectedAudioTrack: AudioTrackOption?
    public private(set) var selectedSubtitleTrack: SubtitleTrackOption?

    public var isSeeking: Bool = false
    public var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?
    public var onPlaybackEnded: (() -> Void)?

    private let subtitleEngine: SubtitleEngine
    private var currentStreamURL: URL?
    private var currentSelection: PreWatchPlaybackSelection?
    private var currentSubtitleStyle = SubtitleAppearanceStyle()
    private var pendingStartSeek: TimeInterval = 0

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
    }

    public func load(selection: PreWatchPlaybackSelection, subtitleStyle: SubtitleAppearanceStyle) {
        currentSelection = selection
        currentSubtitleStyle = subtitleStyle
        errorMessage = nil
        isReady = false
        currentTime = 0
        duration = 0
        bufferedTime = 0

        availableQualities = selection.source.availableQualities
        availableAudioTracks = selection.source.availableAudioTracks
        availableSubtitles = selection.source.availableSubtitles
        selectedQuality = selection.selectedQuality
        selectedAudioTrack = selection.selectedAudioTrack
        selectedSubtitleTrack = selection.selectedSubtitleTrack
        pendingStartSeek = max(0, selection.startPositionSeconds)

        guard let streamURL = resolvePlaybackURL(
            selection: selection,
            quality: selection.selectedQuality,
            audio: selection.selectedAudioTrack
        ) else {
            errorMessage = "No playable stream URL available for this selection."
            return
        }

        replaceCurrentItem(with: streamURL)
        applyQuality(selection.selectedQuality)
        applySubtitle(selection.selectedSubtitleTrack, style: subtitleStyle)
    }

    public func play() {
        player.play()
        if playbackRate != 1.0 {
            player.rate = playbackRate
        }
        isPlaying = true
    }

    public func pause() {
        player.pause()
        isPlaying = false
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to seconds: TimeInterval, exact: Bool = true) {
        let clamped = min(max(seconds, 0), max(duration, seconds))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        let tolerance: CMTime = exact ? .zero : CMTime(seconds: 0.5, preferredTimescale: 600)
        currentTime = clamped
        subtitleEngine.update(forTime: clamped)
        player.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    public func skip(by delta: TimeInterval) {
        seek(to: currentTime + delta, exact: true)
    }

    public func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    public func applyQuality(_ variant: VideoQualityVariant) {
        selectedQuality = variant
        guard let item = player.currentItem else { return }

        if currentSelection?.source.format == .hls {
            item.preferredMaximumResolution = variant.tier.preferredMaximumResolution
            item.preferredPeakBitRate = variant.tier.preferredPeakBitRate
        } else if let variantURL = variant.variantStreamURL, variantURL != currentStreamURL {
            pendingStartSeek = currentTime
            replaceCurrentItem(with: variantURL)
        }
    }

    public func selectAudio(_ track: AudioTrackOption) {
        selectedAudioTrack = track

        if let altVideoURL = track.alternateMuxedVideoURL, altVideoURL != currentStreamURL {
            pendingStartSeek = currentTime
            replaceCurrentItem(with: altVideoURL)
            return
        }

        guard let item = player.currentItem else { return }
        Task { @MainActor in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
            if let matchedOption = Self.matchingOption(in: group, forLanguageCode: track.languageCode, displayName: track.voiceoverStudio) {
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

        if track.format == .embeddedHLS {
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

        if let endToken = endNotificationToken {
            NotificationCenter.default.removeObserver(endToken)
            endNotificationToken = nil
        }
        if let failToken = failNotificationToken {
            NotificationCenter.default.removeObserver(failToken)
            failNotificationToken = nil
        }
        player.replaceCurrentItem(with: nil)
        subtitleEngine.clear()
    }

    private func resolvePlaybackURL(
        selection: PreWatchPlaybackSelection,
        quality: VideoQualityVariant,
        audio: AudioTrackOption
    ) -> URL? {
        if let alt = audio.alternateMuxedVideoURL {
            return alt
        }
        if selection.source.format != .hls, let variantURL = quality.variantStreamURL {
            return variantURL
        }
        return selection.source.playbackURL
    }

    private func replaceCurrentItem(with url: URL) {
        statusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
        if let endToken = endNotificationToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken = failNotificationToken { NotificationCenter.default.removeObserver(failToken) }

        currentStreamURL = url
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 12

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in
                self?.handleItemStatusChange(playerItem)
            }
        }

        loadedRangesObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in
                guard let firstRange = playerItem.loadedTimeRanges.first?.timeRangeValue else { return }
                let endSeconds = CMTimeGetSeconds(CMTimeRangeGetEnd(firstRange))
                if endSeconds.isFinite {
                    self?.bufferedTime = endSeconds
                }
            }
        }

        endNotificationToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.onPlaybackEnded?()
            }
        }

        failNotificationToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                self?.errorMessage = err?.localizedDescription ?? "Playback failed."
                self?.isPlaying = false
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
            if rawDuration.isFinite && rawDuration > 0 {
                duration = rawDuration
            }
            if pendingStartSeek > 1 {
                let target = pendingStartSeek
                pendingStartSeek = 0
                seek(to: target, exact: true)
            }
            if let audio = selectedAudioTrack {
                selectAudio(audio)
            }
            if let sub = selectedSubtitleTrack, sub.format == .embeddedHLS {
                selectEmbeddedLegible(sub, style: currentSubtitleStyle)
            }
        case .failed:
            errorMessage = item.error?.localizedDescription ?? "Unable to load media stream."
            isPlaying = false
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func attachPlayerObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] avPlayer, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch avPlayer.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .playing:
                    self.isBuffering = false
                    self.isPlaying = true
                case .paused:
                    self.isBuffering = false
                    self.isPlaying = false
                @unknown default:
                    break
                }
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isSeeking else { return }
                let sec = CMTimeGetSeconds(time)
                guard sec.isFinite && sec >= 0 else { return }
                self.currentTime = sec
                if let item = self.player.currentItem {
                    let dur = CMTimeGetSeconds(item.duration)
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                }
                self.subtitleEngine.update(forTime: sec)
                self.onTimeUpdate?(sec, self.duration)
            }
        }
    }

    private func selectEmbeddedLegible(_ track: SubtitleTrackOption, style: SubtitleAppearanceStyle) {
        guard let item = player.currentItem else { return }
        item.textStyleRules = Self.makeTextStyleRules(from: style)
        Task { @MainActor in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
            if let matched = Self.matchingOption(in: group, forLanguageCode: track.languageCode, displayName: track.displayName) {
                item.select(matched, in: group)
            }
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

    private static func matchingOption(
        in group: AVMediaSelectionGroup,
        forLanguageCode languageCode: String,
        displayName: String
    ) -> AVMediaSelectionOption? {
        let targetLang = languageCode.lowercased()
        let targetName = displayName.lowercased()
        return group.options.first(where: { opt in
            let optLang = opt.locale?.language.languageCode?.identifier.lowercased()
                ?? opt.extendedLanguageTag?.lowercased()
                ?? ""
            return optLang == targetLang && opt.displayName.lowercased().contains(targetName)
        }) ?? group.options.first(where: { opt in
            let optLang = opt.locale?.language.languageCode?.identifier.lowercased()
                ?? opt.extendedLanguageTag?.lowercased()
                ?? ""
            return optLang == targetLang
        })
    }

    private static func makeTextStyleRules(from style: SubtitleAppearanceStyle) -> [AVTextStyleRule] {
        let fg = rgbaComponents(hex: style.textColorHex, opacity: 1.0)
        let bg = rgbaComponents(hex: style.backgroundColorHex, opacity: style.backgroundOpacity)
        let relativeSize = (style.fontSize / 18.0) * 100.0
        let attrs: [String: Any] = [
            kCMTextMarkupAttribute_ForegroundColorARGB as String: fg,
            kCMTextMarkupAttribute_BackgroundColorARGB as String: bg,
            kCMTextMarkupAttribute_RelativeFontSize as String: relativeSize
        ]
        if let rule = AVTextStyleRule(textMarkupAttributes: attrs) {
            return [rule]
        }
        return []
    }

    private static func rgbaComponents(hex: String, opacity: Double) -> [CGFloat] {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        return [CGFloat(opacity), r, g, b]
    }
}
