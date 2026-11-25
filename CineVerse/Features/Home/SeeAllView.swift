import SwiftUI

public struct SeeAllView: View {
    let section: HomeSectionType
    let container: AppContainer
    let transitionNamespace: Namespace.ID?

    @State private var viewModel: SeeAllViewModel
    @State private var containerWidth: CGFloat = 0

    public init(
        section: HomeSectionType,
        container: AppContainer,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.section = section
        self.container = container
        self.transitionNamespace = transitionNamespace
        _viewModel = State(initialValue: SeeAllViewModel(section: section, container: container))
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
        .navigationTitle(LocalizedStringKey(section.rawValue))
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadInitial(forceRefresh: true)
        }
        .task {
            await viewModel.loadInitial()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            if viewModel.items.isEmpty {
                loadingGrid
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
                        await viewModel.loadInitial(forceRefresh: true)
                    }
                }
                .padding(.top, CVSpacing.xl)
            }
        case .loaded(let items):
            if items.isEmpty {
                EmptyStateView(
                    title: "Nothing Here Yet",
                    message: section.subtitle,
                    symbolName: section.symbolName
                )
                .padding(.top, CVSpacing.xxl)
            } else {
                gridContent(items: items)
            }
        }
    }

    private func gridContent(items: [MediaItem]) -> some View {
        let cardWidth = CVGridLayoutMetrics.cardWidth(for: containerWidth)
        let columns = CVGridLayoutMetrics.columns(for: containerWidth)

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
                            progressFraction: viewModel.progressByMediaID[item.id],
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
        let cardWidth = CVGridLayoutMetrics.cardWidth(for: containerWidth)
        let columns = CVGridLayoutMetrics.columns(for: containerWidth)

        return LazyVGrid(columns: columns, spacing: CVSpacing.lg) {
            ForEach(0..<8, id: \.self) { _ in
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
                        .frame(width: cardWidth * 0.48, height: 10)
                        .cvShimmer(true)
                }
            }
        }
        .padding(.horizontal, CVSpacing.md)
    }
}
