import SwiftUI

public struct SearchResultsView: View {
    let viewModel: SearchViewModel
    let transitionNamespace: Namespace.ID?
    let onSelectMedia: (MediaItem) -> Void

    @State private var containerWidth: CGFloat = 0
    @State private var showAdvancedFilters: Bool = false

    public init(
        viewModel: SearchViewModel,
        transitionNamespace: Namespace.ID? = nil,
        onSelectMedia: @escaping (MediaItem) -> Void
    ) {
        self.viewModel = viewModel
        self.transitionNamespace = transitionNamespace
        self.onSelectMedia = onSelectMedia
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CVSpacing.md) {
                filterBar
                resultsContent
            }
            .padding(.bottom, CVSpacing.xxl)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .sheet(isPresented: $showAdvancedFilters) {
            FilterSheetView(
                initialCriteria: viewModel.filterCriteria,
                catalogRepository: viewModel.catalogRepository,
                settingsStore: viewModel.settingsStore
            ) { updated in
                Task { await viewModel.applyFilterCriteria(updated) }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    FilterChip(
                        title: "All",
                        symbolName: "square.grid.2x2",
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        Task { await viewModel.selectCategory(nil) }
                    }

                    ForEach(MediaProjectType.allCases) { category in
                        FilterChip(
                            title: category.pluralTitle,
                            symbolName: category.symbolName,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            Task { await viewModel.selectCategory(category) }
                        }
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    FilterChip(
                        title: "Available to Watch",
                        symbolName: "checkmark.seal.fill",
                        isSelected: viewModel.onlyAvailableToWatch
                    ) {
                        Task { await viewModel.toggleAvailableToWatchOnly() }
                    }

                    FilterChip(
                        title: "Original / Alt Title",
                        symbolName: "character.book.closed",
                        isSelected: viewModel.searchByOriginalTitleOnly
                    ) {
                        Task { await viewModel.toggleOriginalTitleOnly() }
                    }

                    let extraCount = viewModel.filterCriteria.activeFilterCount
                    FilterChip(
                        title: extraCount > 0 ? "Filters (\(extraCount))" : "Advanced Filters",
                        symbolName: "slider.horizontal.3",
                        isSelected: extraCount > 0
                    ) {
                        showAdvancedFilters = true
                    }

                    if case .loaded(let items) = viewModel.state {
                        Text("\(items.count) \(items.count == 1 ? "result" : "results")")
                            .font(CVFont.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
        .padding(.top, CVSpacing.xs)
    }

    @ViewBuilder
    private var resultsContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingGrid
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.retry() }
            }
            .padding(.top, CVSpacing.xl)
        case .loaded(let items):
            if items.isEmpty {
                let hasFilters = viewModel.filterCriteria.activeFilterCount > 0
                EmptyStateView(
                    title: "No Matching Titles",
                    message: hasFilters
                        ? "No results matched your active category or original-title filters."
                        : "Try checking the spelling or searching by original title.",
                    symbolName: "magnifyingglass",
                    actionTitle: hasFilters ? "Clear Filters" : nil,
                    action: hasFilters ? {
                        Task { await viewModel.resetResultFilters() }
                    } : nil
                )
                .padding(.top, CVSpacing.xl)
            } else {
                grid(items: items)
            }
        }
    }

    private func grid(items: [MediaItem]) -> some View {
        let cardWidth = CVGridLayoutMetrics.cardWidth(for: containerWidth)
        let columns = CVGridLayoutMetrics.columns(for: containerWidth)

        return VStack(spacing: CVSpacing.lg) {
            LazyVGrid(columns: columns, spacing: CVSpacing.lg) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            Haptics.selection()
                            onSelectMedia(item)
                        } label: {
                            PosterCard(
                                item: item,
                                width: cardWidth,
                                transitionNamespace: transitionNamespace,
                                transitionID: item.reference?.id ?? item.id
                            )
                        }
                        .buttonStyle(.plain)

                        let summary = viewModel.availabilityByMediaID[item.id]
                        let status = summary?.status ?? ContentAvailabilityResolver.quickStatus(for: item)
                        AvailabilityBadge(
                            status: status,
                            compact: true,
                            detailText: (summary?.canWatchInApp == true) ? summary?.highestQualityLabel : nil
                        )

                        if let summary, summary.canWatchInApp, !summary.audioLanguages.isEmpty {
                            Text(summary.audioLanguages.prefix(2).joined(separator: ", "))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: cardWidth, alignment: .leading)
                        }
                    }
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

    private var loadingGrid: some View {
        let cardWidth = CVGridLayoutMetrics.cardWidth(for: containerWidth)
        let columns = CVGridLayoutMetrics.columns(for: containerWidth)

        return LazyVGrid(columns: columns, spacing: CVSpacing.lg) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: cardWidth, height: cardWidth * 1.5)
                        .cvShimmer(true)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: cardWidth * 0.78, height: 12)
                        .cvShimmer(true)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: cardWidth * 0.45, height: 10)
                        .cvShimmer(true)
                }
            }
        }
        .padding(.horizontal, CVSpacing.md)
    }
}
