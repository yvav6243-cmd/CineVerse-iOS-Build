import SwiftUI

public struct SearchResultsView: View {
    let viewModel: SearchViewModel
    let transitionNamespace: Namespace.ID?
    let onSelectMedia: (MediaItem) -> Void

    @State private var containerWidth: CGFloat = 0

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

            HStack(spacing: CVSpacing.sm) {
                FilterChip(
                    title: "Original Title Only",
                    symbolName: "character.book.closed",
                    isSelected: viewModel.searchByOriginalTitleOnly
                ) {
                    Task { await viewModel.toggleOriginalTitleOnly() }
                }

                Spacer()

                if case .loaded(let items) = viewModel.state {
                    Text("\(items.count) \(items.count == 1 ? "result" : "results")")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, CVSpacing.md)
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
                let hasFilters = viewModel.selectedCategory != nil || viewModel.searchByOriginalTitleOnly
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
        let cardWidth = resolvedCardWidth
        let columns = [GridItem(.adaptive(minimum: 150, maximum: 195), spacing: CVSpacing.sm)]

        return VStack(spacing: CVSpacing.lg) {
            LazyVGrid(columns: columns, spacing: CVSpacing.lg) {
                ForEach(items) { item in
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
        let cardWidth = resolvedCardWidth
        let columns = [GridItem(.adaptive(minimum: 150, maximum: 195), spacing: CVSpacing.sm)]

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

    private var resolvedCardWidth: CGFloat {
        guard containerWidth > 0 else { return 156 }
        let usable = max(containerWidth - CVSpacing.md * 2, 300)
        let columns = max(2, Int(floor((usable + CVSpacing.sm) / (150 + CVSpacing.sm))))
        let width = floor((usable - CVSpacing.sm * CGFloat(columns - 1)) / CGFloat(columns))
        return min(max(width, 148), 192)
    }
}
