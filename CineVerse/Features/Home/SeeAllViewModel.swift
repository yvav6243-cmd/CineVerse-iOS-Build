import Foundation
import Observation

@MainActor
@Observable
public final class SeeAllViewModel {
    public let section: HomeSectionType

    public private(set) var items: [MediaItem] = []
    public private(set) var progressByMediaID: [String: Double] = [:]
    public private(set) var state: LoadState<[MediaItem]> = .idle
    public private(set) var isLoadingMore: Bool = false
    public private(set) var hasMore: Bool = false
    public private(set) var isMissingTMDBKey: Bool = false

    private let catalogRepository: CatalogRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private let recommendationEngine: RecommendationEngine
    private let settingsStore: SettingsStore

    private var currentPage: Int = 1
    private var loadTask: Task<Void, Never>?

    public init(section: HomeSectionType, container: AppContainer) {
        self.section = section
        self.catalogRepository = container.catalogRepository
        self.progressRepository = container.progressRepository
        self.libraryRepository = container.libraryRepository
        self.recommendationEngine = container.recommendationEngine
        self.settingsStore = container.settingsStore
    }

    public var supportsPagination: Bool {
        switch section {
        case .trendingNow, .newEpisodes, .trendingMovies, .popularAnime, .popularTVShows,
             .upcomingReleases, .topRated, .recentlyAdded:
            return true
        case .continueWatching, .recentlyWatched, .yourFavorites, .recommendedForYou:
            return false
        }
    }

    public func loadInitial(forceRefresh: Bool = false) async {
        if !forceRefresh, case .loaded = state { return }

        loadTask?.cancel()
        currentPage = 1
        isMissingTMDBKey = false
        hasMore = supportsPagination

        if items.isEmpty || forceRefresh {
            state = .loading
        }

        if HomeViewModel.isLocalSection(section) {
            loadLocal()
            return
        }

        let language = settingsStore.contentLanguageCode
        if section == .recommendedForYou {
            let recommended = await recommendationEngine.recommendations(
                language: language,
                forceRefresh: forceRefresh
            )
            items = recommended
            state = .loaded(recommended)
            hasMore = false
            return
        }

        do {
            let fetched = try await catalogRepository.homeFeed(section, language: language)
            items = fetched
            state = .loaded(fetched)
            hasMore = !fetched.isEmpty && supportsPagination
        } catch NetworkError.missingAPIKey(.tmdb) {
            isMissingTMDBKey = true
            hasMore = false
            state = .failed(NetworkError.missingAPIKey(.tmdb).localizedDescription)
        } catch is CancellationError {
            return
        } catch {
            hasMore = false
            state = .failed(error.localizedDescription)
        }
    }

    public func loadNextPageIfNeeded(currentItem: MediaItem) async {
        guard supportsPagination,
              hasMore,
              !isLoadingMore,
              items.suffix(6).contains(where: { $0.id == currentItem.id }) else {
            return
        }

        guard let criteria = discoverCriteria(for: section) else {
            hasMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        let language = settingsStore.contentLanguageCode

        do {
            let pageResult = try await catalogRepository.discover(
                criteria: criteria,
                page: nextPage,
                language: language
            )
            let existingIDs = Set(items.map(\.id))
            let newItems = pageResult.items.filter { !existingIDs.contains($0.id) }
            items.append(contentsOf: newItems)
            currentPage = nextPage
            hasMore = pageResult.hasMore && !newItems.isEmpty
            state = .loaded(items)
        } catch NetworkError.missingAPIKey(.tmdb) {
            isMissingTMDBKey = true
            hasMore = false
        } catch {
            hasMore = false
        }
    }

    private func loadLocal() {
        switch section {
        case .continueWatching:
            let pairs = progressRepository.continueWatchingItems()
            var progressMap: [String: Double] = [:]
            let mapped = pairs.map { pair -> MediaItem in
                progressMap[pair.entry.mediaID] = pair.progress.fraction
                return mediaItem(from: pair.entry)
            }
            progressByMediaID = progressMap
            items = mapped
            state = .loaded(mapped)
        case .recentlyWatched:
            let recent = progressRepository.recentlyWatchedItems(limit: 100)
            items = recent
            state = .loaded(recent)
        case .yourFavorites:
            let favs = libraryRepository.favorites()
            items = favs
            state = .loaded(favs)
        default:
            items = []
            state = .loaded([])
        }
        hasMore = false
    }

    private func discoverCriteria(for section: HomeSectionType) -> CatalogFilterCriteria? {
        switch section {
        case .trendingNow:
            return CatalogFilterCriteria(sortBy: .popularity)
        case .newEpisodes:
            return CatalogFilterCriteria(releaseStatus: .releasing, sortBy: .popularity)
        case .trendingMovies:
            return CatalogFilterCriteria(selectedCategory: .movie, sortBy: .popularity)
        case .popularAnime:
            return CatalogFilterCriteria(selectedCategory: .anime, sortBy: .popularity)
        case .popularTVShows:
            return CatalogFilterCriteria(selectedCategory: .tvSeries, sortBy: .popularity)
        case .topRated:
            return CatalogFilterCriteria(sortBy: .rating)
        case .recentlyAdded:
            return CatalogFilterCriteria(sortBy: .recentlyAdded)
        case .upcomingReleases:
            return CatalogFilterCriteria(releaseStatus: .upcoming, sortBy: .popularity)
        case .continueWatching, .recentlyWatched, .yourFavorites, .recommendedForYou:
            return nil
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
}
