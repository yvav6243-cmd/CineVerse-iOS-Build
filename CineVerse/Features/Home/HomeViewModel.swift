import Foundation
import Observation
import SwiftUI

public struct ContinueWatchingItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let item: MediaItem
    public let progressFraction: Double
    public let subtitle: String

    public init(item: MediaItem, progressFraction: Double, subtitle: String) {
        self.id = item.id
        self.item = item
        self.progressFraction = progressFraction
        self.subtitle = subtitle
    }
}

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var heroCarouselItems: [MediaItem] = []
    public var activeHeroID: String?
    public private(set) var heroPalette: ArtworkPalette = .default
    public private(set) var isHeroLoading: Bool = false

    public private(set) var sectionStates: [HomeSectionType: LoadState<[MediaItem]>] = [:]
    public private(set) var continueWatching: [ContinueWatchingItem] = []
    public private(set) var isMissingTMDBKey: Bool = false
    public private(set) var missingTMDBKeySections: Set<HomeSectionType> = []
    public private(set) var watchlistMediaIDs: Set<String> = []
    public private(set) var hasLoadedOnce: Bool = false

    private let catalogRepository: CatalogRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private let recommendationEngine: RecommendationEngine
    private let settingsStore: SettingsStore

    private var paletteTask: Task<Void, Never>?
    private var lastKnownHasTMDB: Bool
    private var isLoadingHome: Bool = false

    private enum SectionFetchOutcome: Sendable {
        case loaded([MediaItem])
        case missingTMDBKey(String)
        case failed(String)
    }

    public init(container: AppContainer) {
        self.catalogRepository = container.catalogRepository
        self.progressRepository = container.progressRepository
        self.libraryRepository = container.libraryRepository
        self.recommendationEngine = container.recommendationEngine
        self.settingsStore = container.settingsStore
        self.lastKnownHasTMDB = SecretsProvider.tmdbCredential() != nil
    }

    public var visibleSections: [HomeSectionConfiguration] {
        let configured = settingsStore.homeSections
            .filter(\.isVisible)
            .sorted { $0.sortOrder < $1.sortOrder }
        return configured
    }

    public var activeHeroItem: MediaItem? {
        if let activeHeroID, let match = heroCarouselItems.first(where: { $0.id == activeHeroID }) {
            return match
        }
        return heroCarouselItems.first
    }

    public func isInWatchlist(_ item: MediaItem) -> Bool {
        watchlistMediaIDs.contains(item.id)
    }

    public func toggleWatchlist(for item: MediaItem) {
        let added = libraryRepository.toggleWatchlist(for: item)
        if added {
            watchlistMediaIDs.insert(item.id)
            Haptics.notify(.success)
        } else {
            watchlistMediaIDs.remove(item.id)
            Haptics.selection()
        }
    }

    public func handleAppear() async {
        refreshLocalSections()

        let hasTMDBNow = SecretsProvider.tmdbCredential() != nil
        let tmdbChanged = hasTMDBNow != lastKnownHasTMDB
        if !hasLoadedOnce || tmdbChanged {
            guard !isLoadingHome else { return }
            lastKnownHasTMDB = hasTMDBNow
            await loadHome(forceRefresh: tmdbChanged)
        } else if !isLoadingHome {
            await loadNewlyVisibleSectionsIfNeeded()
        }
    }

    public func loadHome(forceRefresh: Bool = false) async {
        isLoadingHome = true
        defer { isLoadingHome = false }

        hasLoadedOnce = true
        lastKnownHasTMDB = SecretsProvider.tmdbCredential() != nil
        refreshLocalSections()

        let visibleRemote = visibleSections
            .map(\.section)
            .filter { !Self.isLocalSection($0) }

        var sectionsToFetch = Set(visibleRemote)
        sectionsToFetch.insert(.trendingNow)
        sectionsToFetch.insert(.trendingMovies)
        sectionsToFetch.insert(.popularAnime)

        for section in sectionsToFetch {
            if sectionStates[section]?.value == nil || forceRefresh {
                sectionStates[section] = .loading
            }
        }
        if heroCarouselItems.isEmpty || forceRefresh {
            isHeroLoading = true
        }

        isMissingTMDBKey = false
        missingTMDBKeySections.removeAll()

        let language = settingsStore.contentLanguageCode
        var fetchedOutcomes: [HomeSectionType: SectionFetchOutcome] = [:]

        await withTaskGroup(of: (HomeSectionType, SectionFetchOutcome).self) { group in
            for section in sectionsToFetch {
                if section == .recommendedForYou {
                    group.addTask { [recommendationEngine] in
                        let items = await recommendationEngine.recommendations(
                            language: language,
                            forceRefresh: forceRefresh
                        )
                        return (section, .loaded(items))
                    }
                } else {
                    group.addTask { [catalogRepository] in
                        do {
                            let items = try await catalogRepository.homeFeed(section, language: language)
                            return (section, .loaded(items))
                        } catch NetworkError.missingAPIKey(.tmdb) {
                            let message = NetworkError.missingAPIKey(.tmdb).localizedDescription
                            return (section, .missingTMDBKey(message))
                        } catch is CancellationError {
                            return (section, .failed(NetworkError.cancelled.localizedDescription))
                        } catch {
                            return (section, .failed(error.localizedDescription))
                        }
                    }
                }
            }

            for await (section, outcome) in group {
                fetchedOutcomes[section] = outcome
            }
        }

        applyOutcomes(fetchedOutcomes)
        updateHeroItems(from: fetchedOutcomes)
        isHeroLoading = false
    }

    public func loadNewlyVisibleSectionsIfNeeded() async {
        let missingVisible = visibleSections
            .map(\.section)
            .filter { section in
                guard !Self.isLocalSection(section) else { return false }
                let state = sectionStates[section] ?? .idle
                if case .idle = state { return true }
                return false
            }

        guard !missingVisible.isEmpty else { return }
        await fetchSections(missingVisible, forceRefresh: false)
    }

    public func retrySection(_ section: HomeSectionType) async {
        if Self.isLocalSection(section) {
            refreshLocalSections()
            return
        }
        await fetchSections([section], forceRefresh: true)
    }

    public func refreshLocalSections() {
        let entries = libraryRepository.allEntries()
        watchlistMediaIDs = Set(entries.filter(\.inWatchlist).map(\.mediaID))

        let continuePairs = progressRepository.continueWatchingItems()
        let mappedContinue = continuePairs.map { pair in
            let item = mediaItem(from: pair.entry)
            let subtitle = Self.continueSubtitle(entry: pair.entry, progress: pair.progress)
            return ContinueWatchingItem(
                item: item,
                progressFraction: pair.progress.fraction,
                subtitle: subtitle
            )
        }
        continueWatching = mappedContinue
        sectionStates[.continueWatching] = .loaded(mappedContinue.map(\.item))

        let recent = progressRepository.recentlyWatchedItems(limit: 20)
        sectionStates[.recentlyWatched] = .loaded(recent)

        let favorites = libraryRepository.favorites()
        sectionStates[.yourFavorites] = .loaded(favorites)
    }

    public func updateHeroPalette(for item: MediaItem?) {
        paletteTask?.cancel()
        guard let item else {
            heroPalette = .default
            return
        }
        let targetURL = item.backdropURL ?? item.posterURL
        paletteTask = Task { [weak self] in
            let palette = await ArtworkPaletteExtractor.shared.palette(for: targetURL)
            guard !Task.isCancelled else { return }
            withAnimation(CVMotion.gentle) {
                self?.heroPalette = palette
            }
        }
    }

    private func fetchSections(_ sections: [HomeSectionType], forceRefresh: Bool) async {
        for section in sections {
            sectionStates[section] = .loading
            missingTMDBKeySections.remove(section)
        }

        let language = settingsStore.contentLanguageCode
        var fetchedOutcomes: [HomeSectionType: SectionFetchOutcome] = [:]

        await withTaskGroup(of: (HomeSectionType, SectionFetchOutcome).self) { group in
            for section in sections {
                if section == .recommendedForYou {
                    group.addTask { [recommendationEngine] in
                        let items = await recommendationEngine.recommendations(
                            language: language,
                            forceRefresh: forceRefresh
                        )
                        return (section, .loaded(items))
                    }
                } else {
                    group.addTask { [catalogRepository] in
                        do {
                            let items = try await catalogRepository.homeFeed(section, language: language)
                            return (section, .loaded(items))
                        } catch NetworkError.missingAPIKey(.tmdb) {
                            let message = NetworkError.missingAPIKey(.tmdb).localizedDescription
                            return (section, .missingTMDBKey(message))
                        } catch is CancellationError {
                            return (section, .failed(NetworkError.cancelled.localizedDescription))
                        } catch {
                            return (section, .failed(error.localizedDescription))
                        }
                    }
                }
            }

            for await (section, outcome) in group {
                fetchedOutcomes[section] = outcome
            }
        }

        applyOutcomes(fetchedOutcomes)
        if heroCarouselItems.isEmpty {
            updateHeroItems(from: fetchedOutcomes)
        }
    }

    private func applyOutcomes(_ outcomes: [HomeSectionType: SectionFetchOutcome]) {
        for (section, outcome) in outcomes {
            switch outcome {
            case .loaded(let items):
                sectionStates[section] = .loaded(items)
                missingTMDBKeySections.remove(section)
            case .missingTMDBKey(let message):
                isMissingTMDBKey = true
                missingTMDBKeySections.insert(section)
                sectionStates[section] = .failed(message)
            case .failed(let message):
                if sectionStates[section]?.value == nil {
                    sectionStates[section] = .failed(message)
                }
            }
        }
    }

    private func updateHeroItems(from outcomes: [HomeSectionType: SectionFetchOutcome]) {
        let openReady = (outcomes[.trendingNow].flatMap { if case .loaded(let v) = $0 { return v } else { return nil } }
            ?? sectionStates[.trendingNow]?.value ?? [])
            .filter { $0.primarySource == .openCinema }

        let movies: [MediaItem]
        if case .loaded(let items) = outcomes[.trendingMovies] {
            movies = items
        } else {
            movies = sectionStates[.trendingMovies]?.value ?? []
        }

        let anime: [MediaItem]
        if case .loaded(let items) = outcomes[.popularAnime] {
            anime = items
        } else {
            anime = sectionStates[.popularAnime]?.value ?? []
        }

        var interleaved: [MediaItem] = Array(openReady.prefix(3))
        let maxPairs = max(movies.count, anime.count)
        for index in 0..<maxPairs {
            if index < movies.count && !interleaved.contains(where: { $0.id == movies[index].id }) {
                interleaved.append(movies[index])
            }
            if index < anime.count && !interleaved.contains(where: { $0.id == anime[index].id }) {
                interleaved.append(anime[index])
            }
        }

        let withBackdrop = interleaved.filter { $0.backdropURL != nil }
        let pool = withBackdrop.count >= 6 ? withBackdrop : interleaved
        let topSix = Array(pool.prefix(6))

        heroCarouselItems = topSix
        if let currentID = activeHeroID, topSix.contains(where: { $0.id == currentID }) {
            updateHeroPalette(for: activeHeroItem)
        } else {
            activeHeroID = topSix.first?.id
            updateHeroPalette(for: topSix.first)
        }
    }

    private func mediaItem(from entry: LibraryEntryRecord) -> MediaItem {
        if let snap = entry.snapshot {
            return snap
        }
        return MediaItem(
            id: entry.mediaID,
            primarySource: MediaReference(id: entry.mediaID)?.provider ?? .openCinema,
            projectType: entry.projectType,
            localizedTitle: entry.title,
            originalTitle: entry.originalTitle,
            synopsis: entry.notes,
            releaseYear: entry.releaseYear,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: entry.genres,
            durationMinutes: entry.episodeDurationMinutes,
            totalSeasons: entry.totalSeasons,
            totalEpisodes: entry.totalEpisodes,
            ratings: MultiSourceRatings(),
            posterURL: entry.posterURL,
            backdropURL: entry.backdropURL
        )
    }

    public static func isLocalSection(_ section: HomeSectionType) -> Bool {
        switch section {
        case .continueWatching, .recentlyWatched, .yourFavorites:
            return true
        case .trendingNow, .newEpisodes, .recentlyAdded, .trendingMovies, .popularAnime, .popularTVShows,
             .upcomingReleases, .recommendedForYou, .topRated:
            return false
        }
    }

    private static func continueSubtitle(
        entry: LibraryEntryRecord,
        progress: PlaybackProgressRecord
    ) -> String {
        let remaining = progress.remainingSeconds
        let remainingText = remaining > 0 ? "\(remaining.formattedRemainingBrief) left" : nil

        if entry.projectType.isEpisodic || progress.season > 0 || progress.episode > 0 {
            let seasonNum = max(progress.season, 1)
            let episodeNum = max(progress.episode, 1)
            let code = "S\(seasonNum) E\(episodeNum)"
            if let remainingText {
                return "\(code) · \(remainingText)"
            }
            return code
        }

        if let remainingText {
            return remainingText
        }
        let percent = Int((progress.fraction * 100).rounded())
        return "\(percent)% watched"
    }
}
