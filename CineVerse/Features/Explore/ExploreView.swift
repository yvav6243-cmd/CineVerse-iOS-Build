import SwiftUI

public struct ExploreView: View {
    let container: AppContainer
    let transitionNamespace: Namespace.ID?

    @State private var viewModel: ExploreViewModel
    @State private var showSurpriseSheet: Bool = false

    public init(container: AppContainer, transitionNamespace: Namespace.ID? = nil) {
        self.container = container
        self.transitionNamespace = transitionNamespace
        _viewModel = State(initialValue: ExploreViewModel(container: container))
    }

    public var body: some View {
        Group {
            if viewModel.isShowingSearchResults {
                SearchResultsView(
                    viewModel: viewModel.searchViewModel,
                    transitionNamespace: transitionNamespace
                ) { item in
                    if let ref = item.reference {
                        container.coordinator.navigate(to: .details(ref))
                    }
                }
            } else {
                exploreOverview
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(LocalizedStringKey("Explore"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Movies, anime, series, original titles"
        )
        .searchSuggestions {
            SearchSuggestionsView(
                matchingHistory: viewModel.searchViewModel.matchingHistory,
                suggestions: viewModel.searchViewModel.suggestions
            )
        }
        .onSubmit(of: .search) {
            Task {
                await viewModel.submitSearch()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitial()
            }
        }
        .sheet(isPresented: $showSurpriseSheet) {
            SurpriseMeView(container: container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var exploreOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CVSpacing.xl) {
                surpriseMeBanner

                if !viewModel.searchViewModel.recentHistory.isEmpty {
                    recentSearchesSection
                }

                if !viewModel.trendingTerms.isEmpty {
                    trendingChipsSection
                }

                categoriesSection
            }
            .padding(.top, CVSpacing.xs)
            .padding(.bottom, CVSpacing.xxl)
        }
        .refreshable {
            await viewModel.refreshTrending()
        }
    }

    private var surpriseMeBanner: some View {
        Button {
            Haptics.impact(.light)
            showSurpriseSheet = true
        } label: {
            HStack(spacing: CVSpacing.md) {
                Image(systemName: "dice.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [CVColor.iris, Color(hex: "#9B6DFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey("Surprise Me"))
                        .font(CVFont.sectionTitle)
                        .foregroundStyle(.primary)
                    Text("Spin a random pick from the global catalog or your watchlist")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(CVSpacing.md)
            .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous), interactive: true)
            .padding(.horizontal, CVSpacing.md)
        }
        .buttonStyle(.plain)
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Recent Searches",
                symbolName: "clock.arrow.circlepath",
                actionTitle: "Clear All"
            ) {
                viewModel.clearAllRecentQueries()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    ForEach(viewModel.searchViewModel.recentHistory, id: \.normalizedQuery) { record in
                        HStack(spacing: 6) {
                            Button {
                                Task {
                                    await viewModel.selectRecentQuery(record)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(record.query)
                                        .font(CVFont.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.deleteRecentQuery(record)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(record.query)")
                        }
                        .padding(.leading, CVSpacing.sm)
                        .padding(.trailing, CVSpacing.xs)
                        .padding(.vertical, 7)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }

    private var trendingChipsSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Trending Now",
                symbolName: "flame.fill",
                actionTitle: nil
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    ForEach(viewModel.trendingTerms, id: \.self) { term in
                        FilterChip(
                            title: term,
                            symbolName: "sparkles",
                            isSelected: false
                        ) {
                            Task {
                                await viewModel.selectQuickChip(term)
                            }
                        }
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Browse Categories",
                subtitle: "Explore across cinema, anime, series, and specials",
                symbolName: "square.grid.2x2",
                actionTitle: "All"
            ) {
                container.coordinator.navigate(to: .catalog(nil))
            }

            CategoryGridView { category in
                container.coordinator.navigate(to: .catalog(category))
            }
        }
    }
}
