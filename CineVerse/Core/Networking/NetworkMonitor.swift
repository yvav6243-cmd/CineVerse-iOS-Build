import Foundation
import Network
import Observation

@MainActor
@Observable
public final class NetworkMonitor {
    public private(set) var isOnline: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.cineverse.network-monitor")

    public init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
