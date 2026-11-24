import Foundation
import Observation

@MainActor
@Observable
public final class CatalogBrowseViewModel {
    public private(set) var criteria: CatalogFilterCriteria
    public private(set) var items: [MediaItem] = []
    public private(set) var state: LoadState<[MediaItem]> = .idle
    public private(set) var isLoadingMore: Bool = false
    public private(set) var hasMore: Bool = true
    public private(set) var isMissingTMDBKey: Bool = false

    private let catalogRepository: CatalogRepositoryProtocol
    private let settingsStore: SettingsStore

    private var currentPage: Int = 1
    private var fetchTask: Task<Void, Never>?
    private var lastKnownHasTMDB: Bool

    public init(initialCategory: MediaProjectType?, container: AppContainer) {
        self.criteria = CatalogFilterCriteria(selectedCategory: initialCategory)
        self.catalogRepository = container.catalogRepository
        self.settingsStore = container.settingsStore
        self.lastKnownHasTMDB = SecretsProvider.tmdbCredential() != nil
    }

    public var navigationTitle: String {
        criteria.selectedCategory?.pluralTitle ?? "All Catalogs"
    }

    public func handleAppear() async {
        let hasTMDBNow = SecretsProvider.tmdbCredential() != nil
        if case .idle = state {
            lastKnownHasTMDB = hasTMDBNow
            await loadFirstPage()
        } else if hasTMDBNow != lastKnownHasTMDB {
            lastKnownHasTMDB = hasTMDBNow
            await loadFirstPage()
        }
    }

    public func loadFirstPage() async {
        fetchTask?.cancel()
        currentPage = 1
        hasMore = true
        isMissingTMDBKey = false
        isLoadingMore = false
        items = []
        state = .loading

        let activeCriteria = criteria
        let language = settingsStore.contentLanguageCode

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let pageResult = try await self.catalogRepository.discover(
                    criteria: activeCriteria,
                    page: 1,
                    language: language
                )
                guard !Task.isCancelled else { return }
                self.items = pageResult.items
                self.currentPage = 1
                self.hasMore = pageResult.hasMore && !pageResult.items.isEmpty
                self.state = .loaded(pageResult.items)
            } catch NetworkError.missingAPIKey(.tmdb) {
                guard !Task.isCancelled else { return }
                self.isMissingTMDBKey = true
                self.hasMore = false
                self.state = .failed(NetworkError.missingAPIKey(.tmdb).localizedDescription)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.hasMore = false
                self.state = .failed(error.localizedDescription)
            }
        }

        fetchTask = task
        await task.value
    }

    public func loadNextPageIfNeeded(currentItem: MediaItem) async {
        guard hasMore,
              !isLoadingMore,
              items.suffix(6).contains(where: { $0.id == currentItem.id }) else {
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        let activeCriteria = criteria
        let language = settingsStore.contentLanguageCode

        do {
            let pageResult = try await catalogRepository.discover(
                criteria: activeCriteria,
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

    public func updateSort(_ sortOption: CatalogSortOption) async {
        guard criteria.sortBy != sortOption else { return }
        criteria.sortBy = sortOption
        await loadFirstPage()
    }

    public func applyCriteria(_ updated: CatalogFilterCriteria) async {
        criteria = updated
        await loadFirstPage()
    }

    public func resetFilters() async {
        criteria.reset()
        await loadFirstPage()
    }
}
