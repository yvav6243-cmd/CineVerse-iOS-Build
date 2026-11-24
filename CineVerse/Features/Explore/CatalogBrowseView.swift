import SwiftUI

public struct CatalogBrowseView: View {
    let container: AppContainer
    let transitionNamespace: Namespace.ID?

    @State private var viewModel: CatalogBrowseViewModel
    @State private var showFilterSheet: Bool = false
    @State private var containerWidth: CGFloat = 0

    public init(
        initialCategory: MediaProjectType?,
        container: AppContainer,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.container = container
        self.transitionNamespace = transitionNamespace
        _viewModel = State(initialValue: CatalogBrowseViewModel(initialCategory: initialCategory, container: container))
    }

    public var body: some View {
        ScrollView {
            content
                .padding(.vertical, CVSpacing.md)
        }
        .background(Color(.systemBackground))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                sortMenu
                filterButton
            }
        }
        .refreshable {
            await viewModel.loadFirstPage()
        }
        .onAppear {
            Task {
                await viewModel.handleAppear()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(
                initialCriteria: viewModel.criteria,
                catalogRepository: container.catalogRepository,
                settingsStore: container.settingsStore
            ) { updated in
                Task {
                    await viewModel.applyCriteria(updated)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(CatalogSortOption.allCases) { option in
                Button {
                    Haptics.selection()
                    Task {
                        await viewModel.updateSort(option)
                    }
                } label: {
                    if viewModel.criteria.sortBy == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Label(option.rawValue, systemImage: option.symbolName)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort Catalog")
    }

    private var filterButton: some View {
        Button {
            Haptics.selection()
            showFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body)

                let count = viewModel.criteria.activeFilterCount
                if count > 0 {
                    Text(String(count))
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(CVColor.iris, in: Capsule(style: .continuous))
                        .offset(x: 8, y: -6)
                }
            }
        }
        .accessibilityLabel("Filter Catalog")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            if viewModel.items.isEmpty {
                VStack(spacing: CVSpacing.lg) {
                    ShimmerRail()
                    ShimmerRail()
                }
            } else {
                gridContent(items: viewModel.items)
            }
        case .failed(let message):
            if viewModel.isMissingTMDBKey {
                ErrorStateView(
                    title: "TMDB API Key Required",
                    message: message,
                    symbolName: "key.fill",
                    actionTitle: "Open API Keys"
                ) {
                    container.coordinator.navigate(to: .apiKeys)
                }
                .padding(.top, CVSpacing.xl)
            } else {
                ErrorStateView(message: message) {
                    Task {
                        await viewModel.loadFirstPage()
                    }
                }
                .padding(.top, CVSpacing.xl)
            }
        case .loaded(let items):
            if items.isEmpty {
                EmptyStateView(
                    title: "No Matching Titles",
                    message: viewModel.criteria.activeFilterCount > 0
                        ? "Try loosening or resetting your active catalog filters."
                        : "No titles were returned for this category right now.",
                    symbolName: "film.stack",
                    actionTitle: viewModel.criteria.activeFilterCount > 0 ? "Reset Filters" : "Try Again"
                ) {
                    Task {
                        if viewModel.criteria.activeFilterCount > 0 {
                            await viewModel.resetFilters()
                        } else {
                            await viewModel.loadFirstPage()
                        }
                    }
                }
                .padding(.top, CVSpacing.xl)
            } else {
                gridContent(items: items)
            }
        }
    }

    private func gridContent(items: [MediaItem]) -> some View {
        let cardWidth = resolvedCardWidth
        let columns = [GridItem(.adaptive(minimum: 150, maximum: 195), spacing: CVSpacing.sm)]

        return VStack(spacing: CVSpacing.lg) {
            LazyVGrid(columns: columns, spacing: CVSpacing.lg) {
                ForEach(items) { item in
                    Button {
                        Haptics.selection()
                        if let ref = item.reference {
                            container.coordinator.navigate(to: .details(ref))
                        }
                    } label: {
                        PosterCard(
                            item: item,
                            width: cardWidth,
                            transitionNamespace: transitionNamespace,
                            transitionID: item.reference?.id ?? item.id
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await viewModel.loadNextPageIfNeeded(currentItem: item)
                        }
                    }
                }
            }
            .padding(.horizontal, CVSpacing.md)

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(CVColor.iris)
                    .padding(.vertical, CVSpacing.md)
            }
        }
    }

    private var resolvedCardWidth: CGFloat {
        guard containerWidth > 0 else { return 156 }
        let usable = max(containerWidth - CVSpacing.md * 2, 300)
        let columns = max(2, Int(floor((usable + CVSpacing.sm) / (150 + CVSpacing.sm))))
        let width = floor((usable - CVSpacing.sm * CGFloat(columns - 1)) / CGFloat(columns))
        return min(max(width, 148), 192)
    }
}
