import Foundation
import Observation

public struct PrimaryWatchCTA: Equatable, Sendable {
    public let title: String
    public let targetEpisode: MediaEpisode?
    public let startPositionSeconds: TimeInterval
    public let isResume: Bool

    public init(
        title: String,
        targetEpisode: MediaEpisode? = nil,
        startPositionSeconds: TimeInterval = 0,
        isResume: Bool = false
    ) {
        self.title = title
        self.targetEpisode = targetEpisode
        self.startPositionSeconds = startPositionSeconds
        self.isResume = isResume
    }
}

@MainActor
@Observable
public final class MediaDetailsViewModel {
    public let reference: MediaReference

    public private(set) var state: LoadState<MediaItem> = .idle
    public private(set) var item: MediaItem?
    public private(set) var palette: ArtworkPalette = .default
    public private(set) var libraryEntry: LibraryEntryRecord?
    public private(set) var progressByEpisodeKey: [String: PlaybackProgressRecord] = [:]
    public private(set) var similarItems: [MediaItem] = []
    public private(set) var isLoadingSimilar: Bool = false
    public private(set) var selectedSeasonNumber: Int = 1
    public private(set) var isLoadingSeason: Bool = false
    public private(set) var seasonLoadError: String?
    public private(set) var collections: [CustomCollectionRecord] = []
    public private(set) var memberCollectionIDs: Set<UUID> = []
    public private(set) var shareURL: URL?

    private let detailsRepository: DetailsRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let collectionsRepository: CollectionsRepositoryProtocol
    private let trackerService: TrackerService
    private let settingsStore: SettingsStore
    private let networkMonitor: NetworkMonitor
    private let widgetWriter: WidgetSnapshotWriter?

    public init(
        reference: MediaReference,
        detailsRepository: DetailsRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        collectionsRepository: CollectionsRepositoryProtocol,
        trackerService: TrackerService,
        settingsStore: SettingsStore,
        networkMonitor: NetworkMonitor,
        widgetWriter: WidgetSnapshotWriter? = nil
    ) {
        self.reference = reference
        self.detailsRepository = detailsRepository
        self.libraryRepository = libraryRepository
        self.progressRepository = progressRepository
        self.collectionsRepository = collectionsRepository
        self.trackerService = trackerService
        self.settingsStore = settingsStore
        self.networkMonitor = networkMonitor
        self.widgetWriter = widgetWriter
        self.shareURL = reference.shareURL
    }

    public func load(forceReload: Bool = false) async {
        if !forceReload, case .loaded = state {
            refreshLocalState()
            return
        }

        refreshLocalState()
        let offlineSnapshot = libraryEntry?.snapshot

        if !networkMonitor.isOnline, let offlineSnapshot {
            item = offlineSnapshot
            state = .loaded(offlineSnapshot)
            updateShareURL()
        } else if item == nil {
            state = .loading
        }

        do {
            let fetched = try await detailsRepository.details(
                for: reference,
                language: settingsStore.contentLanguageCode,
                watchRegion: settingsStore.watchRegion,
                offlineSnapshot: offlineSnapshot
            )
            item = fetched
            state = .loaded(fetched)
            refreshLocalState()
            updateShareURL()

            if fetched.projectType.isEpisodic {
                let targetSeason = preferredInitialSeasonNumber(for: fetched)
                selectedSeasonNumber = targetSeason
                await loadEpisodesForSeasonIfNeeded(seasonNumber: targetSeason)
            }

            await loadSecondaryData(for: fetched)
        } catch {
            if let fallback = item ?? offlineSnapshot {
                item = fallback
                state = .loaded(fallback)
                updateShareURL()
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    public func refreshLocalState() {
        let targetID = item?.id ?? reference.id
        libraryEntry = libraryRepository.entry(for: targetID)
        let records = progressRepository.allProgress(for: targetID)
        var mapped: [String: PlaybackProgressRecord] = [:]
        for record in records {
            mapped[Self.progressKey(season: record.season, episode: record.episode)] = record
        }
        progressByEpisodeKey = mapped
        collections = collectionsRepository.allCollections()
        memberCollectionIDs = collectionsRepository.collectionIDs(containing: targetID)
    }

    public func selectSeason(_ seasonNumber: Int) async {
        selectedSeasonNumber = seasonNumber
        seasonLoadError = nil
        await loadEpisodesForSeasonIfNeeded(seasonNumber: seasonNumber)
    }

    public func loadEpisodesForSeasonIfNeeded(seasonNumber: Int) async {
        guard var currentItem = item, currentItem.projectType.isEpisodic else { return }
        guard let index = currentItem.seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) else {
            return
        }
        guard currentItem.seasons[index].episodes.isEmpty else { return }

        isLoadingSeason = true
        seasonLoadError = nil
        defer { isLoadingSeason = false }

        do {
            let fetchedSeason = try await detailsRepository.season(
                for: reference,
                seasonNumber: seasonNumber,
                language: settingsStore.contentLanguageCode,
                defaultDuration: max(currentItem.durationMinutes, 24)
            )
            if let refreshedIndex = item?.seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) {
                currentItem = item ?? currentItem
                currentItem.seasons[refreshedIndex] = fetchedSeason
                item = currentItem
                state = .loaded(currentItem)
            }
        } catch {
            seasonLoadError = error.localizedDescription
        }
    }

    public var selectedSeason: MediaSeason? {
        guard let item else { return nil }
        return item.seasons.first(where: { $0.seasonNumber == selectedSeasonNumber }) ?? item.seasons.first
    }

    public var episodesForSelectedSeason: [MediaEpisode] {
        (selectedSeason?.episodes ?? []).sorted { $0.episodeNumber < $1.episodeNumber }
    }

    public func progress(for episode: MediaEpisode) -> PlaybackProgressRecord? {
        progressByEpisodeKey[Self.progressKey(season: episode.seasonNumber, episode: episode.episodeNumber)]
    }

    public var movieProgress: PlaybackProgressRecord? {
        progressByEpisodeKey[Self.progressKey(season: 0, episode: 0)]
    }

    public func isEpisodeWatched(_ episode: MediaEpisode) -> Bool {
        progress(for: episode)?.isWatched ?? false
    }

    public var isAllWatched: Bool {
        guard let item else { return false }
        if libraryEntry?.status == .completed {
            return true
        }
        if !item.projectType.isEpisodic {
            return movieProgress?.isWatched ?? false
        }
        let watchedCount = progressByEpisodeKey.values.filter(\.isWatched).count
        return watchedCount > 0 && watchedCount >= max(item.totalEpisodes, 1)
    }

    public var primaryWatchCTA: PrimaryWatchCTA {
        guard let item else {
            return PrimaryWatchCTA(title: "Watch")
        }

        if !item.projectType.isEpisodic {
            if let prog = movieProgress, !prog.isWatched, prog.positionSeconds > 5, prog.fraction < 0.92 {
                return PrimaryWatchCTA(
                    title: "Continue · \(prog.positionSeconds.formattedPlaybackTime)",
                    targetEpisode: nil,
                    startPositionSeconds: prog.positionSeconds,
                    isResume: true
                )
            }
            if isAllWatched {
                return PrimaryWatchCTA(title: "Watch Again")
            }
            return PrimaryWatchCTA(title: "Watch")
        }

        let inProgressRecord = progressByEpisodeKey.values
            .filter { $0.season > 0 && !$0.isWatched && $0.positionSeconds > 5 && $0.fraction < 0.92 }
            .max(by: { $0.lastUpdated < $1.lastUpdated })

        if let active = inProgressRecord {
            let matchingEpisode = findEpisode(season: active.season, episode: active.episode, in: item)
            return PrimaryWatchCTA(
                title: "Continue S\(active.season) E\(active.episode) · \(active.positionSeconds.formattedPlaybackTime)",
                targetEpisode: matchingEpisode,
                startPositionSeconds: active.positionSeconds,
                isResume: true
            )
        }

        if let nextEp = trackerService.nextUnwatchedEpisode(for: item) {
            if let epProg = progress(for: nextEp), !epProg.isWatched, epProg.positionSeconds > 5 {
                return PrimaryWatchCTA(
                    title: "Continue \(nextEp.formattedCode) · \(epProg.positionSeconds.formattedPlaybackTime)",
                    targetEpisode: nextEp,
                    startPositionSeconds: epProg.positionSeconds,
                    isResume: true
                )
            }
            let hasAnyWatched = progressByEpisodeKey.values.contains(where: \.isWatched)
            if hasAnyWatched && !isEpisodeWatched(nextEp) {
                return PrimaryWatchCTA(
                    title: "Watch \(nextEp.formattedCode)",
                    targetEpisode: nextEp
                )
            }
            if isEpisodeWatched(nextEp) {
                return PrimaryWatchCTA(title: "Watch Again", targetEpisode: nextEp)
            }
            return PrimaryWatchCTA(title: "Watch", targetEpisode: nextEp)
        }

        return PrimaryWatchCTA(title: isAllWatched ? "Watch Again" : "Watch")
    }

    public func toggleWatchlist() {
        guard let item else { return }
        _ = libraryRepository.toggleWatchlist(for: item)
        refreshLocalState()
    }

    public func toggleFavorite() {
        guard let item else { return }
        _ = libraryRepository.toggleFavorite(for: item)
        refreshLocalState()
    }

    public func setStatus(_ status: WatchTrackingStatus?) {
        guard let item else { return }
        libraryRepository.setStatus(status, for: item)
        refreshLocalState()
    }

    public func setPersonalRating(_ rating: Double?) {
        guard let item else { return }
        let normalized = rating.flatMap { $0 > 0 ? min(max($0, 0.5), 10.0) : nil }
        libraryRepository.setPersonalRating(normalized, for: item)
        refreshLocalState()
    }

    public func setNotes(_ notes: String) {
        guard let item else { return }
        libraryRepository.setNotes(notes, for: item)
        refreshLocalState()
    }

    public func markAllWatched() {
        guard let item else { return }
        trackerService.markAllWatched(item: item)
        refreshLocalState()
        refreshWidgetsInBackground()
    }

    public func toggleEpisodeWatched(_ episode: MediaEpisode) {
        guard let item else { return }
        let newWatched = !isEpisodeWatched(episode)
        trackerService.markEpisodeWatched(
            item: item,
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            episodeTitle: episode.title,
            durationMinutes: max(episode.durationMinutes, item.durationMinutes, 1),
            watched: newWatched
        )
        refreshLocalState()
        refreshWidgetsInBackground()
    }

    public func toggleCollectionMembership(collectionID: UUID) {
        guard let item else { return }
        if memberCollectionIDs.contains(collectionID) {
            collectionsRepository.remove(mediaID: item.id, from: collectionID)
        } else {
            collectionsRepository.add(item: item, to: collectionID)
        }
        refreshLocalState()
    }

    public func createCollection(name: String, symbolName: String = "folder.fill") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let item else { return }
        let created = collectionsRepository.createCollection(name: trimmed, symbolName: symbolName)
        collectionsRepository.add(item: item, to: created.id)
        refreshLocalState()
    }

    public func setAlertsEnabled(_ enabled: Bool) {
        guard let item else { return }
        _ = libraryRepository.upsert(from: item)
        libraryRepository.setAlertsEnabled(enabled, mediaID: item.id)
        refreshLocalState()
    }

    public func updateShareURL() {
        shareURL = item?.reference?.shareURL ?? reference.shareURL
    }

    private func loadSecondaryData(for loadedItem: MediaItem) async {
        async let paletteTask = ArtworkPaletteExtractor.shared.palette(
            for: loadedItem.backdropURL ?? loadedItem.posterURL
        )

        isLoadingSimilar = true
        async let similarTask = detailsRepository.similarItems(
            for: loadedItem,
            language: settingsStore.contentLanguageCode
        )

        let extractedPalette = await paletteTask
        let resolvedSimilar = await similarTask

        palette = extractedPalette
        similarItems = resolvedSimilar
        isLoadingSimilar = false
    }

    private func preferredInitialSeasonNumber(for mediaItem: MediaItem) -> Int {
        if let active = progressByEpisodeKey.values
            .filter({ $0.season > 0 && !$0.isWatched && $0.positionSeconds > 5 })
            .max(by: { $0.lastUpdated < $1.lastUpdated }) {
            return active.season
        }
        if let nextUnwatched = trackerService.nextUnwatchedEpisode(for: mediaItem) {
            return nextUnwatched.seasonNumber
        }
        return mediaItem.seasons.first?.seasonNumber ?? 1
    }

    private func findEpisode(season: Int, episode: Int, in item: MediaItem) -> MediaEpisode? {
        item.seasons
            .first(where: { $0.seasonNumber == season })?
            .episodes
            .first(where: { $0.episodeNumber == episode })
    }

    private func refreshWidgetsInBackground() {
        guard let widgetWriter else { return }
        Task {
            await widgetWriter.refreshWidgets()
        }
    }

    private static func progressKey(season: Int, episode: Int) -> String {
        "\(season):\(episode)"
    }
}
