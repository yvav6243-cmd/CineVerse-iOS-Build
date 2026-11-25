import Foundation
import Observation

@MainActor
@Observable
public final class PlaybackSetupViewModel {
    public private(set) var mediaItem: MediaItem?
    public private(set) var selectedEpisode: MediaEpisode?
    public private(set) var allSources: [VideoSourceDescriptor] = []
    public private(set) var playableSources: [VideoSourceDescriptor] = []
    public private(set) var officialSources: [VideoSourceDescriptor] = []
    public private(set) var selectedSource: VideoSourceDescriptor?

    public var selectedQuality: VideoQualityVariant?
    public var selectedAudioTrack: AudioTrackOption?
    public var selectedSubtitleTrack: SubtitleTrackOption?

    public private(set) var isResolving: Bool = false
    public private(set) var isInspecting: Bool = false
    public private(set) var subtitleImportError: String?
    public private(set) var availabilitySummary: ContentAvailabilitySummary?

    public var effectiveAvailabilityStatus: ContentAvailabilityStatus {
        if let summary = availabilitySummary {
            return summary.status
        }
        if let mediaItem {
            return ContentAvailabilityResolver.quickStatus(for: mediaItem)
        }
        return .informationOnly
    }

    private let sourceManager: VideoSourceManager
    private let libraryRepository: LibraryRepositoryProtocol
    private let settingsStore: SettingsStore

    public init(
        sourceManager: VideoSourceManager,
        libraryRepository: LibraryRepositoryProtocol,
        settingsStore: SettingsStore
    ) {
        self.sourceManager = sourceManager
        self.libraryRepository = libraryRepository
        self.settingsStore = settingsStore
    }

    public var hasPlayableSource: Bool {
        selectedSource != nil && !playableSources.isEmpty
    }

    public var availableQualities: [VideoQualityVariant] {
        selectedSource?.availableQualities ?? []
    }

    public var availableAudioTracks: [AudioTrackOption] {
        selectedSource?.availableAudioTracks ?? []
    }

    public var availableSubtitles: [SubtitleTrackOption] {
        selectedSource?.availableSubtitles ?? []
    }

    public func isUserSource(_ source: VideoSourceDescriptor) -> Bool {
        guard source.id.hasPrefix("direct:") || source.id.hasPrefix("local:") else {
            return false
        }
        let parts = source.id.split(separator: ":", maxSplits: 1)
        return parts.count == 2 && UUID(uuidString: String(parts[1])) != nil
    }

    public func loadSources(for item: MediaItem, episode: MediaEpisode?) async {
        mediaItem = item
        selectedEpisode = episode
        isResolving = true

        let resolved = await sourceManager.resolveSources(
            for: item,
            episode: episode,
            verifyReachability: false
        )
        allSources = resolved
        playableSources = resolved.filter { $0.isAvailable && $0.format.isDirectlyPlayable }
        officialSources = resolved.filter { $0.format == .externalOfficialService }
        availabilitySummary = ContentAvailabilityResolver.resolve(item: item, sources: resolved)
        isResolving = false

        let entry = libraryRepository.entry(for: item.id)
        let preferredID = entry?.preferredSourceID
        let currentID = selectedSource?.id

        let targetSource = playableSources.first(where: { $0.id == preferredID })
            ?? playableSources.first(where: { $0.id == currentID })
            ?? playableSources.first

        if let targetSource {
            await selectSource(targetSource, entry: entry)
        } else {
            selectedSource = nil
            selectedQuality = nil
            selectedAudioTrack = nil
            selectedSubtitleTrack = nil
        }

        // Background health check: verify online status, measure latency, and prune unreachable links
        if !playableSources.isEmpty {
            let snapshotID = item.id
            let snapshotEpID = episode?.id
            let verified = await sourceManager.verifySourcesHealth(resolved)
            guard mediaItem?.id == snapshotID && selectedEpisode?.id == snapshotEpID else { return }
            allSources = verified
            let healthyPlayable = verified.filter { $0.isAvailable && $0.format.isDirectlyPlayable }
            playableSources = healthyPlayable
            availabilitySummary = ContentAvailabilityResolver.resolve(item: item, sources: verified)
            if let currentSel = selectedSource, !healthyPlayable.contains(where: { $0.id == currentSel.id }) {
                if let fallback = healthyPlayable.first {
                    await selectSource(fallback, entry: entry)
                } else {
                    selectedSource = nil
                }
            } else if let currentSel = selectedSource,
                      let updatedSel = healthyPlayable.first(where: { $0.id == currentSel.id }) {
                var merged = currentSel
                merged.healthStatus = updatedSel.healthStatus
                selectedSource = merged
            }
        }
    }

    public func selectEpisode(_ episode: MediaEpisode?) async {
        guard let mediaItem else { return }
        await loadSources(for: mediaItem, episode: episode)
    }

    public func selectSource(_ source: VideoSourceDescriptor) async {
        let entry = mediaItem.flatMap { libraryRepository.entry(for: $0.id) }
        await selectSource(source, entry: entry)
        persistCurrentPreferences()
    }

    public func selectQuality(_ quality: VideoQualityVariant) {
        selectedQuality = quality
        persistCurrentPreferences()
    }

    public func selectAudioTrack(_ track: AudioTrackOption) {
        selectedAudioTrack = track
        persistCurrentPreferences()
    }

    public func selectSubtitleTrack(_ track: SubtitleTrackOption?) {
        selectedSubtitleTrack = track
        persistCurrentPreferences()
    }

    public func deleteSource(_ source: VideoSourceDescriptor) async {
        guard isUserSource(source) else { return }
        sourceManager.deleteUserSource(descriptorID: source.id)
        if let mediaItem {
            await loadSources(for: mediaItem, episode: selectedEpisode)
        }
    }

    public func importSubtitle(url: URL) async {
        subtitleImportError = nil
        let ext = url.pathExtension.lowercased()
        let format: SubtitleFormat = ext == "vtt" ? .webVTT : .srt

        do {
            let imported = try LocalVideoStore.shared.importSubtitle(from: url)
            let localURL = LocalVideoStore.shared.resolveURL(forRelativePath: imported.relativePath)
            let langCode = settingsStore.defaultSubtitleLanguage == "off"
                ? "en"
                : settingsStore.defaultSubtitleLanguage
            let storedDTO = StoredSubtitleDTO(
                languageCode: langCode,
                displayName: imported.fileName,
                relativePathOrURL: imported.relativePath,
                formatRaw: format.rawValue
            )

            if let source = selectedSource, isUserSource(source) {
                sourceManager.attachSubtitle(toSourceID: source.id, subtitle: storedDTO)
            }

            let newTrack = SubtitleTrackOption(
                id: storedDTO.id,
                languageCode: langCode,
                displayName: imported.fileName,
                format: format,
                externalURL: localURL
            )

            if var current = selectedSource {
                if !current.availableSubtitles.contains(where: { $0.id == newTrack.id }) {
                    current.availableSubtitles.append(newTrack)
                }
                selectedSource = current
                if let idx = playableSources.firstIndex(where: { $0.id == current.id }) {
                    playableSources[idx] = current
                }
            }
            selectedSubtitleTrack = newTrack
            persistCurrentPreferences()
        } catch {
            subtitleImportError = error.localizedDescription
        }
    }

    public func buildPlaybackSelection(startPositionSeconds: TimeInterval = 0) -> PreWatchPlaybackSelection? {
        guard let mediaItem, let source = selectedSource else {
            return nil
        }

        let resolvedQuality = selectedQuality
            ?? source.availableQualities.first
            ?? VideoQualityVariant(id: "auto", tier: .auto, variantStreamURL: source.playbackURL)

        let resolvedAudio = selectedAudioTrack
            ?? source.availableAudioTracks.first
            ?? AudioTrackOption(
                id: "default-audio-\(mediaItem.originalLanguage)",
                languageCode: mediaItem.originalLanguage,
                displayName: LanguageCatalog.displayName(forLanguageCode: mediaItem.originalLanguage),
                voiceoverStudio: "Default Audio",
                isOriginal: true,
                isDefault: true
            )

        persistCurrentPreferences()

        return PreWatchPlaybackSelection(
            mediaItem: mediaItem,
            episode: selectedEpisode,
            source: source,
            selectedQuality: resolvedQuality,
            selectedAudioTrack: resolvedAudio,
            selectedSubtitleTrack: selectedSubtitleTrack,
            startPositionSeconds: max(0, startPositionSeconds)
        )
    }

    public func buildDirectTrailerSelection(url: URL, for item: MediaItem) async -> PreWatchPlaybackSelection {
        let lang = item.originalLanguage.nilIfEmpty ?? "en"
        let defaultAudio = AudioTrackOption(
            id: "trailer-audio-\(lang)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Original Audio",
            isOriginal: true,
            isDefault: true
        )
        let isHLS = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.lowercased().contains(".m3u8")
        let descriptor = VideoSourceDescriptor(
            id: "trailer:\(item.id)",
            providerID: "trailer",
            providerName: "Official Trailer",
            sourceDescription: "Direct trailer stream",
            isAvailable: true,
            format: isHLS ? .hls : .mp4,
            playbackURL: url,
            availableAudioTracks: [defaultAudio]
        )
        let inspected = await sourceManager.inspect(descriptor, originalLanguage: item.originalLanguage)
        let quality = inspected.availableQualities.first
            ?? VideoQualityVariant(id: "auto", tier: .auto, variantStreamURL: url)
        let audio = inspected.availableAudioTracks.first ?? defaultAudio
        return PreWatchPlaybackSelection(
            mediaItem: item,
            episode: nil,
            source: inspected,
            selectedQuality: quality,
            selectedAudioTrack: audio,
            selectedSubtitleTrack: nil,
            startPositionSeconds: 0
        )
    }

    private func selectSource(_ source: VideoSourceDescriptor, entry: LibraryEntryRecord?) async {
        isInspecting = true
        let originalLang = mediaItem?.originalLanguage ?? "en"
        let inspected = await sourceManager.inspect(source, originalLanguage: originalLang)
        selectedSource = inspected

        if let idx = playableSources.firstIndex(where: { $0.id == inspected.id }) {
            playableSources[idx] = inspected
        }

        applyDefaultTrackSelections(from: inspected, entry: entry)
        isInspecting = false
    }

    private func applyDefaultTrackSelections(
        from descriptor: VideoSourceDescriptor,
        entry: LibraryEntryRecord?
    ) {
        let preferredQualityTier: VideoQualityTier? = entry?.preferredQuality ?? (
            settingsStore.defaultQuality == .auto && descriptor.format == .hls ? .auto : (
                settingsStore.defaultQuality == .auto ? nil : settingsStore.defaultQuality
            )
        )
        selectedQuality = PlaybackQualityDiagnostics.selectPreferredVariant(
            from: descriptor.availableQualities,
            preferredTier: preferredQualityTier,
            format: descriptor.format
        )

        let preferredAudioLang = (entry?.preferredAudioLanguage ?? settingsStore.defaultAudioLanguage).lowercased()
        selectedAudioTrack = descriptor.availableAudioTracks.first(where: { $0.languageCode.lowercased() == preferredAudioLang })
            ?? descriptor.availableAudioTracks.first(where: { $0.isDefault })
            ?? descriptor.availableAudioTracks.first(where: { $0.isOriginal })
            ?? descriptor.availableAudioTracks.first

        let preferredSubLang = (entry?.preferredSubtitleLanguage ?? settingsStore.defaultSubtitleLanguage).lowercased()
        if preferredSubLang == "off" {
            selectedSubtitleTrack = nil
        } else {
            selectedSubtitleTrack = descriptor.availableSubtitles.first(where: { $0.languageCode.lowercased() == preferredSubLang })
                ?? descriptor.availableSubtitles.first(where: { $0.isDefault })
        }
    }

    private func persistCurrentPreferences() {
        guard let mediaItem,
              libraryRepository.entry(for: mediaItem.id) != nil else {
            return
        }
        libraryRepository.savePlaybackPreferences(
            mediaID: mediaItem.id,
            sourceID: selectedSource?.id,
            audioLang: selectedAudioTrack?.languageCode,
            subtitleLang: selectedSubtitleTrack?.languageCode ?? "off",
            quality: selectedQuality?.tier
        )
    }
}
