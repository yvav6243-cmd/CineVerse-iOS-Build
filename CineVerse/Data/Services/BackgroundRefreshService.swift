import Foundation
import BackgroundTasks

public final class BackgroundRefreshService: @unchecked Sendable {
    public static let taskIdentifier = "com.cineverse.app.refresh-airing"

    private var refreshHandler: (@Sendable () async -> Void)?

    public init() {}

    public func register(handler: @escaping @Sendable () async -> Void) {
        self.refreshHandler = handler
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleAppRefresh(task: refreshTask)
        }
    }

    public func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            CVLogger.app.debug("BGTask schedule skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let workTask = Task { [weak self] in
            if let handler = self?.refreshHandler {
                await handler()
            }
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            workTask.cancel()
        }
    }
}
