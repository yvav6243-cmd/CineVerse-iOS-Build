import Foundation
import Observation

@MainActor
@Observable
public final class SearchViewModel {
    public var query: String = "" {
        didSet {
            if query != oldValue {
                onQueryChanged()
            }
        }
    }

    public private(set) var submittedQuery: String = ""
    public var filterCriteria = CatalogFilterCriteria()
    public var selectedCategory: MediaProjectType? {
        get { filterCriteria.selectedCategory }
        set { filterCriteria.selectedCategory = newValue }
    }
    public var searchByOriginalTitleOnly: Bool {
        get { filterCriteria.searchByOriginalTitleOnly }
        set { filterCriteria.searchByOriginalTitleOnly = newValue }
    }
    public var onlyAvailableToWatch: Bool {
        get { filterCriteria.onlyAvailableToWatch }
        set { filterCriteria.onlyAvailableToWatch = newValue }
    }

    public let catalogRepository: CatalogRepositoryProtocol
    private let searchHistoryRepository: SearchHistoryRepositoryProtocol
    public let settingsStore: SettingsStore

    public private(set) var suggestions: [String] = []
    public private(set) var matchingHistory: [SearchHistoryRecord] = []
    public private(set) var recentHistory: [SearchHistoryRecord] = []

    public private(set) var results: [MediaItem] = []
    public private(set) var state: LoadState<[MediaItem]> = .idle
    public private(set) var isLoadingMore: Bool = false
    public private(set) var hasMore: Bool = false

    private let suggestionDebouncer = Debouncer(delay: .milliseconds(300))
    private let liveSearchDebouncer = Debouncer(delay: .milliseconds(450))

    private var currentPage: Int = 1
    private var searchTask: Task<Void, Never>?

    public init(
        catalogRepository: CatalogRepositoryProtocol,
        searchHistoryRepository: SearchHistoryRepositoryProtocol,
        settingsStore: SettingsStore
    ) {
        self.catalogRepository = catalogRepository
        self.searchHistoryRepository = searchHistoryRepository
        self.settingsStore = settingsStore
        loadHistory()
    }

    public convenience init(container: AppContainer) {
        self.init(
            catalogRepository: container.catalogRepository,
            searchHistoryRepository: container.searchHistoryRepository,
            settingsStore: container.settingsStore
        )
    }

    public var hasActiveQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func loadHistory() {
        recentHistory = searchHistoryRepository.recentQueries(limit: 20)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        updateMatchingHistory(for: trimmed)
    }

    public func deleteHistory(_ record: SearchHistoryRecord) {
        searchHistoryRepository.deleteQuery(record.normalizedQuery)
        loadHistory()
    }

    public func clearAllHistory() {
        searchHistoryRepository.clearAll()
        loadHistory()
    }

    public func submitSearch(saveHistory: Bool = true) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        liveSearchDebouncer.cancel()
        if saveHistory {
            searchHistoryRepository.saveQuery(trimmed)
            loadHistory()
        }

        if submittedQuery == trimmed, case .loaded = state {
            return
        }

        await performSearch(query: trimmed, page: 1, append: false)
    }

    public func submitQuickQuery(_ text: String) async {
        query = text
        await submitSearch(saveHistory: true)
    }

    public func selectCategory(_ category: MediaProjectType?) async {
        guard selectedCategory != category else { return }
        selectedCategory = category
        await rerunActiveSearchIfNeeded()
    }

    public func toggleOriginalTitleOnly() async {
        filterCriteria.searchByOriginalTitleOnly.toggle()
        await rerunActiveSearchIfNeeded()
    }

    public func toggleAvailableToWatchOnly() async {
        filterCriteria.onlyAvailableToWatch.toggle()
        await rerunActiveSearchIfNeeded()
    }

    public func applyFilterCriteria(_ updated: CatalogFilterCriteria) async {
        filterCriteria = updated
        if activeSearchQuery.isEmpty && updated.activeFilterCount > 0 {
            await performSearch(query: "", page: 1, append: false)
        } else {
            await rerunActiveSearchIfNeeded()
        }
    }

    public func resetResultFilters() async {
        filterCriteria.reset()
        await rerunActiveSearchIfNeeded()
    }

    public func retry() async {
        let active = activeSearchQuery
        guard !active.isEmpty else { return }
        await performSearch(query: active, page: 1, append: false)
    }

    public func loadNextPageIfNeeded(currentItem: MediaItem) async {
        let active = activeSearchQuery
        guard !active.isEmpty,
              hasMore,
              !isLoadingMore,
              results.suffix(6).contains(where: { $0.id == currentItem.id }) else {
            return
        }
        await performSearch(query: active, page: currentPage + 1, append: true)
    }

    private var activeSearchQuery: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? submittedQuery : trimmed
    }

    private func onQueryChanged() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        updateMatchingHistory(for: trimmed)

        guard !trimmed.isEmpty else {
            suggestionDebouncer.cancel()
            liveSearchDebouncer.cancel()
            searchTask?.cancel()
            suggestions = []
            submittedQuery = ""
            results = []
            state = .idle
            hasMore = false
            currentPage = 1
            isLoadingMore = false
            return
        }

        if trimmed.count >= 2 {
            let language = settingsStore.contentLanguageCode
            suggestionDebouncer.schedule { [weak self] in
                guard let self else { return }
                let latest = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard latest == trimmed else { return }
                let fetched = await self.catalogRepository.suggestions(prefix: trimmed, language: language)
                guard self.query.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                self.suggestions = fetched
            }
        } else {
            suggestionDebouncer.cancel()
            suggestions = []
        }

        if trimmed != submittedQuery {
            liveSearchDebouncer.schedule { [weak self] in
                guard let self else { return }
                let latest = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !latest.isEmpty, latest == trimmed else { return }
                await self.performSearch(query: latest, page: 1, append: false)
            }
        }
    }

    private func updateMatchingHistory(for trimmedQuery: String) {
        guard !trimmedQuery.isEmpty else {
            matchingHistory = Array(recentHistory.prefix(5))
            return
        }
        let lower = trimmedQuery.lowercased()
        matchingHistory = Array(
            recentHistory
                .filter { $0.query.lowercased().contains(lower) }
                .prefix(5)
        )
    }

    private func rerunActiveSearchIfNeeded() async {
        let active = activeSearchQuery
        guard !active.isEmpty else { return }
        liveSearchDebouncer.cancel()
        await performSearch(query: active, page: 1, append: false)
    }

    private func performSearch(query: String, page: Int, append: Bool) async {
        if append {
            isLoadingMore = true
        } else {
            searchTask?.cancel()
            submittedQuery = query
            currentPage = 1
            hasMore = false
            results = []
            state = .loading
        }

        let criteria = filterCriteria
        let language = settingsStore.contentLanguageCode

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let pageResult = try await self.catalogRepository.search(
                    query: query,
                    criteria: criteria,
                    page: page,
                    language: language
                )
                guard !Task.isCancelled else { return }

                if append {
                    let existing = Set(self.results.map(\.id))
                    let newItems = pageResult.items.filter { !existing.contains($0.id) }
                    self.results.append(contentsOf: newItems)
                    self.currentPage = page
                    self.hasMore = pageResult.hasMore && !newItems.isEmpty
                    self.state = .loaded(self.results)
                    self.isLoadingMore = false
                } else {
                    self.results = pageResult.items
                    self.currentPage = 1
                    self.hasMore = pageResult.hasMore && !pageResult.items.isEmpty
                    self.state = .loaded(pageResult.items)
                }
            } catch is CancellationError {
                if append {
                    self.isLoadingMore = false
                }
            } catch {
                if append {
                    self.isLoadingMore = false
                } else {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }

        if !append {
            searchTask = task
        }
        await task.value
    }
}
