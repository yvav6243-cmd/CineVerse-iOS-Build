import SwiftUI
import Observation

public enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home
    case explore
    case myList
    case tracker
    case profile
}

public enum Route: Hashable, Sendable {
    case details(MediaReference)
    case seeAll(HomeSectionType)
    case catalog(MediaProjectType?)
    case collection(UUID)
    case calendar
    case history
    case settings
    case subtitleStyle
    case storage
    case backup
    case videoSources
    case apiKeys
    case about
}

@MainActor
@Observable
public final class AppCoordinator {
    public var selectedTab: AppTab = .home
    public var homePath = NavigationPath()
    public var explorePath = NavigationPath()
    public var myListPath = NavigationPath()
    public var trackerPath = NavigationPath()
    public var profilePath = NavigationPath()

    public var playerSelection: PreWatchPlaybackSelection?

    public init() {}

    public func navigate(to route: Route) {
        switch selectedTab {
        case .home:
            homePath.append(route)
        case .explore:
            explorePath.append(route)
        case .myList:
            myListPath.append(route)
        case .tracker:
            trackerPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }

    public func presentPlayer(_ selection: PreWatchPlaybackSelection) {
        playerSelection = selection
    }

    public func popToRoot(tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        switch target {
        case .home: homePath = NavigationPath()
        case .explore: explorePath = NavigationPath()
        case .myList: myListPath = NavigationPath()
        case .tracker: trackerPath = NavigationPath()
        case .profile: profilePath = NavigationPath()
        }
    }
}
