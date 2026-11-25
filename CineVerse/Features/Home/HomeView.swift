import SwiftUI

public struct HomeView: View {
    let container: AppContainer
    let transitionNamespace: Namespace.ID?

    @State private var viewModel: HomeViewModel
    @State private var showSectionEditor: Bool = false
    @State private var showSurpriseSheet: Bool = false

    public init(container: AppContainer, transitionNamespace: Namespace.ID? = nil) {
        self.container = container
        self.transitionNamespace = transitionNamespace
        _viewModel = State(initialValue: HomeViewModel(container: container))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CVSpacing.xl) {
                heroSection

                if viewModel.isMissingTMDBKey,
                   !viewModel.visibleSections.contains(where: {
                       $0.section == .trendingMovies && viewModel.missingTMDBKeySections.contains($0.section)
                   }) {
                    tmdbSetupPromptCard
                }

                ForEach(viewModel.visibleSections) { config in
                    sectionView(for: config.section)
                }
            }
            .padding(.top, CVSpacing.xs)
            .padding(.bottom, CVSpacing.xxl)
        }
        .background {
            AmbientBackground(
                artworkURL: viewModel.activeHeroItem?.backdropURL ?? viewModel.activeHeroItem?.posterURL,
                palette: viewModel.heroPalette
            )
        }
        .navigationTitle(LocalizedStringKey("Home"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    container.coordinator.navigate(to: .calendar)
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Premiere Calendar")

                Button {
                    Haptics.selection()
                    showSurpriseSheet = true
                } label: {
                    Image(systemName: "dice")
                }
                .accessibilityLabel("Surprise Me")

                Button {
                    Haptics.selection()
                    showSectionEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Customize Home Sections")
            }
        }
        .refreshable {
            await viewModel.loadHome(forceRefresh: true)
        }
        .onAppear {
            Task {
                await viewModel.handleAppear()
            }
        }
        .onChange(of: viewModel.activeHeroID) { _, _ in
            viewModel.updateHeroPalette(for: viewModel.activeHeroItem)
        }
        .sheet(isPresented: $showSectionEditor) {
            HomeSectionEditorView(settingsStore: container.settingsStore) {
                Task {
                    await viewModel.loadNewlyVisibleSectionsIfNeeded()
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSurpriseSheet) {
            SurpriseMeView(container: container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if !viewModel.heroCarouselItems.isEmpty {
            HeroCarouselView(
                items: viewModel.heroCarouselItems,
                activeItemID: $viewModel.activeHeroID,
                isInWatchlist: { viewModel.isInWatchlist($0) },
                onOpen: { openDetails(for: $0) },
                onToggleWatchlist: { viewModel.toggleWatchlist(for: $0) }
            )
        } else if viewModel.isHeroLoading {
            ShimmerHeroCard()
        }
    }

    private var tmdbSetupPromptCard: some View {
        CompactHintCard(
            symbolName: "key.fill",
            title: "Connect TMDB API Key",
            subtitle: "Add your TMDB key in Profile → API Keys to unlock Trending Movies, cinema posters, and full search.",
            actionTitle: "API Keys"
        ) {
            container.coordinator.navigate(to: .apiKeys)
        }
    }

    @ViewBuilder
    private func sectionView(for section: HomeSectionType) -> some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: section.displayTitle,
                subtitle: section.subtitle,
                symbolName: section.symbolName,
                actionTitle: "See All"
            ) {
                container.coordinator.navigate(to: .seeAll(section))
            }

            if section == .continueWatching {
                continueWatchingBody
            } else {
                standardSectionBody(for: section)
            }
        }
    }

    @ViewBuilder
    private var continueWatchingBody: some View {
        if viewModel.continueWatching.isEmpty {
            emptyHintCard(for: .continueWatching)
        } else {
            MediaRail(items: viewModel.continueWatching) { entry in
                Button {
                    Haptics.selection()
                    openDetails(for: entry.item)
                } label: {
                    WideProgressCard(
                        title: entry.item.localizedTitle,
                        subtitle: entry.subtitle,
                        imageURL: entry.item.backdropURL ?? entry.item.posterURL,
                        projectType: entry.item.projectType,
                        progressFraction: entry.progressFraction
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func standardSectionBody(for section: HomeSectionType) -> some View {
        let state = viewModel.sectionStates[section] ?? .idle

        switch state {
        case .idle, .loading:
            ShimmerRail()
        case .failed(let message):
            if viewModel.missingTMDBKeySections.contains(section) {
                CompactHintCard(
                    symbolName: "key.fill",
                    title: "TMDB Key Required",
                    subtitle: "Configure your TMDB key in Profile → API Keys to load \(section.rawValue).",
                    actionTitle: "Set Up"
                ) {
                    container.coordinator.navigate(to: .apiKeys)
                }
            } else {
                ErrorStateView(message: message) {
                    Task {
                        await viewModel.retrySection(section)
                    }
                }
            }
        case .loaded(let items):
            if items.isEmpty {
                emptyHintCard(for: section)
            } else {
                MediaRail(items: items) { item in
                    Button {
                        Haptics.selection()
                        openDetails(for: item)
                    } label: {
                        PosterCard(
                            item: item,
                            transitionNamespace: transitionNamespace,
                            transitionID: item.reference?.id ?? item.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyHintCard(for section: HomeSectionType) -> some View {
        switch section {
        case .continueWatching:
            CompactHintCard(
                symbolName: "play.tv",
                title: "Nothing in Progress",
                subtitle: "Start watching any movie, anime, or series to pick up right where you left off.",
                actionTitle: "Explore"
            ) {
                container.coordinator.selectedTab = .explore
            }
        case .recentlyWatched:
            CompactHintCard(
                symbolName: "clock.arrow.circlepath",
                title: "No Recent History",
                subtitle: "Projects and episodes you finish watching will appear in your timeline.",
                actionTitle: "Browse"
            ) {
                container.coordinator.selectedTab = .explore
            }
        case .yourFavorites:
            CompactHintCard(
                symbolName: "heart",
                title: "No Favorites Yet",
                subtitle: "Mark titles as favorites on their details screen to keep them handy here.",
                actionTitle: "Discover"
            ) {
                container.coordinator.selectedTab = .explore
            }
        case .recommendedForYou:
            CompactHintCard(
                symbolName: "wand.and.stars",
                title: "Building Your Recommendations",
                subtitle: "Rate or track a few projects to tailor recommendations to your taste.",
                actionTitle: "Explore"
            ) {
                container.coordinator.selectedTab = .explore
            }
        default:
            CompactHintCard(
                symbolName: section.symbolName,
                title: "No Titles Available",
                subtitle: "Pull down to refresh or check your network connection.",
                actionTitle: "Refresh"
            ) {
                Task {
                    await viewModel.retrySection(section)
                }
            }
        }
    }

    private func openDetails(for item: MediaItem) {
        if let ref = item.reference {
            container.coordinator.navigate(to: .details(ref))
        }
    }
}
