import Foundation
import SwiftData
import Observation

@MainActor
@Observable
public final class VideoSourceManager {
    private let providers: [VideoSourceProvider]
    private let inspector: MediaSourceInspector
    private let healthChecker: SourceHealthChecker
    private let modelContext: ModelContext
    private let videoStore: LocalVideoStore

    public init(
        modelContext: ModelContext,
        httpClient: HTTPClient,
        internetArchiveService: InternetArchiveServiceProtocol,
        iTunesService: ITunesCatalogServiceProtocol = ITunesCatalogService(httpClient: URLSessionHTTPClient()),
        wikimediaService: WikimediaCinemaServiceProtocol? = nil,
        videoStore: LocalVideoStore = .shared
    ) {
        self.modelContext = modelContext
        self.videoStore = videoStore
        self.inspector = MediaSourceInspector(httpClient: httpClient)
        self.healthChecker = SourceHealthChecker(httpClient: httpClient)

        let fetchClosure: @MainActor (String, Int?, Int?) -> [UserVideoSourceDTO] = { mediaID, season, episode in
            let descriptor = FetchDescriptor<UserVideoSourceRecord>(
                predicate: #Predicate { $0.mediaID == mediaID },
                sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
            )
            let all = (try? modelContext.fetch(descriptor)) ?? []
            return all.filter { record in
                if record.season == nil && record.episode == nil {
                    return true
                }
                return record.season == season && record.episode == episode
            }
            .map { $0.toDTO() }
        }

        let resolvedWikimedia = wikimediaService ?? WikimediaCinemaService(httpClient: httpClient)
        self.providers = [
            LocalFileSourceProvider(videoStore: videoStore, fetchSources: fetchClosure),
            DirectLinkSourceProvider(videoStore: videoStore, fetchSources: fetchClosure),
            OpenStreamSourceProvider(iTunesService: iTunesService),
            WikimediaSourceProvider(service: resolvedWikimedia),
            InternetArchiveSourceProvider(service: internetArchiveService),
            OfficialServicesProvider()
        ]
    }

    public func resolveSources(
        for item: MediaItem,
        episode: MediaEpisode?,
        verifyReachability: Bool = false
    ) async -> [VideoSourceDescriptor] {
        var batches: [(providerIndex: Int, items: [VideoSourceDescriptor])] = []

        await withTaskGroup(of: (Int, [VideoSourceDescriptor]).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    let result = await provider.sources(for: item, episode: episode)
                    return (index, result)
                }
            }
            for await batch in group {
                batches.append(batch)
            }
        }

        let orderedEntries = batches
            .sorted { $0.providerIndex < $1.providerIndex }
            .flatMap { batch in
                batch.items.enumerated().map { offset, descriptor in
                    (
                        formatPriority: Self.priority(for: descriptor.format),
                        providerRank: Self.providerRank(for: descriptor.providerID, fallback: batch.providerIndex),
                        originalIndex: offset,
                        descriptor: descriptor
                    )
                }
            }

        let sorted = orderedEntries.sorted { lhs, rhs in
            if lhs.formatPriority != rhs.formatPriority {
                return lhs.formatPriority < rhs.formatPriority
            }
            if lhs.providerRank != rhs.providerRank {
                return lhs.providerRank < rhs.providerRank
            }
            return lhs.originalIndex < rhs.originalIndex
        }
        .map(\.descriptor)

        guard verifyReachability else {
            return sorted.filter { $0.isAvailable || $0.format == .externalOfficialService }
        }

        return await verifySourcesHealth(sorted)
    }

    public func verifySourcesHealth(_ descriptors: [VideoSourceDescriptor]) async -> [VideoSourceDescriptor] {
        var indexed: [(Int, VideoSourceDescriptor)] = []
        await withTaskGroup(of: (Int, VideoSourceDescriptor).self) { group in
            for (idx, desc) in descriptors.enumerated() {
                group.addTask { [healthChecker] in
                    let checked = await healthChecker.check(desc)
                    return (idx, checked)
                }
            }
            for await pair in group {
                indexed.append(pair)
            }
        }
        return indexed
            .sorted { $0.0 < $1.0 }
            .map(\.1)
            .filter { $0.format == .externalOfficialService || ($0.isAvailable && $0.healthStatus.isHealthyOrUnchecked) }
    }

    public func inspect(_ descriptor: VideoSourceDescriptor, originalLanguage: String) async -> VideoSourceDescriptor {
        await inspector.inspect(descriptor, originalLanguage: originalLanguage)
    }

    public func addDirectLinkSource(
        mediaID: String,
        season: Int?,
        episode: Int?,
        label: String,
        url: URL,
        subtitles: [StoredSubtitleDTO] = []
    ) {
        let record = UserVideoSourceRecord(
            mediaID: mediaID,
            season: season,
            episode: episode,
            kind: .directLink,
            urlString: url.absoluteString,
            label: label,
            subtitles: subtitles
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    public func addLocalFileSource(
        mediaID: String,
        season: Int?,
        episode: Int?,
        label: String,
        importedFile: ImportedLocalFileInfo,
        subtitles: [StoredSubtitleDTO] = []
    ) {
        let record = UserVideoSourceRecord(
            mediaID: mediaID,
            season: season,
            episode: episode,
            kind: .localFile,
            relativeFilePath: importedFile.relativePath,
            label: label.nilIfEmpty ?? importedFile.fileName,
            subtitles: subtitles
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    public func attachSubtitle(
        toSourceID descriptorID: String,
        subtitle: StoredSubtitleDTO
    ) {
        guard let uuid = extractRecordUUID(from: descriptorID) else { return }
        let descriptor = FetchDescriptor<UserVideoSourceRecord>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let record = try? modelContext.fetch(descriptor).first else { return }
        var subs = record.subtitles
        subs.append(subtitle)
        record.subtitles = subs
        try? modelContext.save()
    }

    public func deleteUserSource(descriptorID: String) {
        guard let uuid = extractRecordUUID(from: descriptorID) else { return }
        let descriptor = FetchDescriptor<UserVideoSourceRecord>(
            predicate: #Predicate { $0.id == uuid }
        )
        guard let record = try? modelContext.fetch(descriptor).first else { return }
        if record.kind == .localFile, let rel = record.relativeFilePath {
            videoStore.deleteFile(relativePath: rel)
        }
        modelContext.delete(record)
        try? modelContext.save()
    }

    public func nextEpisodeSelection(
        after current: PreWatchPlaybackSelection,
        nextEpisode: MediaEpisode
    ) async -> PreWatchPlaybackSelection? {
        let nextSources = await resolveSources(for: current.mediaItem, episode: nextEpisode)
        let playable = nextSources.filter { $0.isAvailable && $0.format.isDirectlyPlayable }
        guard let chosenSource = playable.first(where: { $0.providerID == current.source.providerID }) ?? playable.first else {
            return nil
        }
        let inspected = await inspect(chosenSource, originalLanguage: current.mediaItem.originalLanguage)
        let quality = inspected.availableQualities.first(where: { $0.tier == current.selectedQuality.tier })
            ?? PlaybackQualityDiagnostics.selectPreferredVariant(from: inspected.availableQualities)
            ?? VideoQualityVariant(id: "auto", tier: .auto, variantStreamURL: inspected.playbackURL)
        let audio = inspected.availableAudioTracks.first(where: { $0.languageCode == current.selectedAudioTrack.languageCode })
            ?? inspected.availableAudioTracks.first
            ?? AudioTrackOption(id: "default", languageCode: current.mediaItem.originalLanguage, displayName: "Default", voiceoverStudio: "Audio", isOriginal: true, isDefault: true)
        let sub = current.selectedSubtitleTrack.flatMap { prevSub in
            inspected.availableSubtitles.first(where: { $0.languageCode == prevSub.languageCode })
        }

        return PreWatchPlaybackSelection(
            mediaItem: current.mediaItem,
            episode: nextEpisode,
            source: inspected,
            selectedQuality: quality,
            selectedAudioTrack: audio,
            selectedSubtitleTrack: sub,
            startPositionSeconds: 0
        )
    }

    private func extractRecordUUID(from descriptorID: String) -> UUID? {
        let parts = descriptorID.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    private static func priority(for format: VideoStreamFormat) -> Int {
        switch format {
        case .localFile: return 0
        case .hls, .mp4, .webm, .dash: return 1
        case .externalOfficialService: return 2
        }
    }

    private static func providerRank(for providerID: String, fallback: Int) -> Int {
        switch providerID {
        case "local_file": return 0
        case "direct_link": return 1
        case "open_stream": return 2
        case "wikimedia_cinema": return 3
        case "internet_archive": return 4
        case "official_services": return 5
        default: return 10 + fallback
        }
    }
}
