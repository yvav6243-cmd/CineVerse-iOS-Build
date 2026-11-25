import SwiftUI

public struct RootTabView: View {
    let container: AppContainer
    @Namespace private var posterTransitionNamespace

    public init(container: AppContainer) {
        self.container = container
    }

    public var body: some View {
        @Bindable var coordinator = container.coordinator

        VStack(spacing: 0) {
            if !container.networkMonitor.isOnline {
                offlineBanner
            }

            tabContent(coordinator: $coordinator)
        }
        .fullScreenCover(item: $coordinator.playerSelection) { selection in
            PlayerView(
                selection: selection,
                httpClient: container.httpClient,
                progressRepository: container.progressRepository,
                libraryRepository: container.libraryRepository,
                trackerService: container.trackerService,
                sourceManager: container.sourceManager,
                settingsStore: container.settingsStore
            )
        }
    }

    @ViewBuilder
    private func tabContent(coordinator: Bindable<AppCoordinator>) -> some View {
        let tabView = TabView(selection: coordinator.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: coordinator.homePath) {
                    HomeView(container: container, transitionNamespace: posterTransitionNamespace)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("Explore", systemImage: "sparkle.magnifyingglass", value: AppTab.explore) {
                NavigationStack(path: coordinator.explorePath) {
                    ExploreView(container: container, transitionNamespace: posterTransitionNamespace)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("My List", systemImage: "rectangle.stack.badge.play", value: AppTab.myList) {
                NavigationStack(path: coordinator.myListPath) {
                    LibraryView(container: container)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("Tracker", systemImage: "chart.bar.xaxis", value: AppTab.tracker) {
                NavigationStack(path: coordinator.trackerPath) {
                    TrackerView(container: container)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                NavigationStack(path: coordinator.profilePath) {
                    ProfileView(container: container)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .tint(CVColor.iris)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabView.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabView
        }
        #else
        tabView
        #endif
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .details(let ref):
            MediaDetailsView(
                reference: ref,
                container: container,
                transitionNamespace: posterTransitionNamespace
            )
            .cvIfAvailableZoomTransition(id: ref.id, in: posterTransitionNamespace)
        case .seeAll(let section):
            SeeAllView(section: section, container: container, transitionNamespace: posterTransitionNamespace)
        case .catalog(let category):
            CatalogBrowseView(initialCategory: category, container: container, transitionNamespace: posterTransitionNamespace)
        case .collection(let id):
            CollectionDetailView(collectionID: id, container: container)
        case .calendar:
            PremiereCalendarView(container: container)
        case .history:
            WatchHistoryView(container: container)
        case .settings:
            SettingsView(
                settingsStore: container.settingsStore,
                alertScheduler: container.alertScheduler
            )
        case .subtitleStyle:
            SubtitleStyleSettingsView(settingsStore: container.settingsStore)
        case .storage:
            StorageManagementView(responseCache: container.responseCache)
        case .backup:
            BackupView(container: container)
        case .apiKeys:
            APIKeysView(tmdbService: container.tmdbService)
        case .about:
            AboutView()
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: CVSpacing.xs) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CVColor.warning)
            Text("Offline Mode — Showing cached titles & your local library")
                .font(CVFont.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, CVSpacing.md)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
