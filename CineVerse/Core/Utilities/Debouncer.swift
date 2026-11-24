import Foundation

@MainActor
public final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: Duration

    public init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    public func schedule(_ action: @escaping @MainActor () async -> Void) {
        task?.cancel()
        let delay = self.delay
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
