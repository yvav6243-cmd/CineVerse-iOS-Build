import Foundation
import Observation

@MainActor
@Observable
public final class ExploreViewModel {
    public let searchViewModel: SearchViewModel

    public private(set) var trendingTerms: [String] = []
    public private(set) var isLoadingTrending: Bool = false

    private let catalogRepository: CatalogRepositoryProtocol
    private let settingsStore: SettingsStore
    private var hasLoadedTrending: Bool = false

    public init(container: AppContainer) {
        self.catalogRepository = container.catalogRepository
        self.settingsStore = container.settingsStore
        self.searchViewModel = SearchViewModel(container: container)
    }

    public var searchText: String {
        get { searchViewModel.query }
        set { searchViewModel.query = newValue }
    }

    public var isShowingSearchResults: Bool {
        searchViewModel.hasActiveQuery
    }

    public func loadInitial() async {
        searchViewModel.loadHistory()
        guard !hasLoadedTrending, !isLoadingTrending else { return }
        await loadTrendingChips()
    }

    public func refreshTrending() async {
        await loadTrendingChips()
    }

    public func submitSearch() async {
        await searchViewModel.submitSearch(saveHistory: true)
    }

    public func selectQuickChip(_ term: String) async {
        Haptics.selection()
        await searchViewModel.submitQuickQuery(term)
    }

    public func selectRecentQuery(_ record: SearchHistoryRecord) async {
        Haptics.selection()
        await searchViewModel.submitQuickQuery(record.query)
    }

    public func deleteRecentQuery(_ record: SearchHistoryRecord) {
        Haptics.selection()
        searchViewModel.deleteHistory(record)
    }

    public func clearAllRecentQueries() {
        Haptics.impact(.light)
        searchViewModel.clearAllHistory()
    }

    private func loadTrendingChips() async {
        isLoadingTrending = true
        defer {
            isLoadingTrending = false
            hasLoadedTrending = true
        }

        let language = settingsStore.contentLanguageCode

        var collected: [MediaItem] = []
        await withTaskGroup(of: [MediaItem].self) { group in
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.popularAnime, language: language)) ?? []
            }
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.popularTVShows, language: language)) ?? []
            }
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.trendingMovies, language: language)) ?? []
            }

            for await batch in group {
                collected.append(contentsOf: batch)
            }
        }

        let sorted = collected.sorted { $0.popularityScore > $1.popularityScore }
        var seen: Set<String> = []
        var terms: [String] = []

        for item in sorted {
            let title = item.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 28 else { continue }
            let key = title.lowercased()
            if seen.insert(key).inserted {
                terms.append(title)
            }
            if terms.count >= 10 { break }
        }

        trendingTerms = terms
    }
}
