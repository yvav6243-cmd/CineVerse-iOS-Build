import Foundation

@MainActor
public enum DeepLinkRouter {
    public static func handle(url: URL, coordinator: AppCoordinator) {
        guard url.scheme?.lowercased() == "cineverse" else { return }
        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "media":
            guard let rawID = pathComponents.first,
                  let decoded = rawID.removingPercentEncoding,
                  let ref = MediaReference(id: decoded) else {
                return
            }
            coordinator.navigate(to: .details(ref))

        case "tab":
            if let tabName = pathComponents.first?.lowercased() {
                switch tabName {
                case "home": coordinator.selectedTab = .home
                case "explore": coordinator.selectedTab = .explore
                case "mylist", "list": coordinator.selectedTab = .myList
                case "tracker": coordinator.selectedTab = .tracker
                case "profile": coordinator.selectedTab = .profile
                default: break
                }
            }

        case "calendar":
            coordinator.selectedTab = .home
            coordinator.navigate(to: .calendar)

        default:
            break
        }
    }
}
