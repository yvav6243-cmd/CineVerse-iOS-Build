import Foundation

public actor RateLimiter {
    private var lastRequestByHost: [String: ContinuousClock.Instant] = [:]

    private let minimumIntervals: [String: Duration] = [
        "graphql.anilist.co": .milliseconds(700),
        "api.tvmaze.com": .milliseconds(500),
        "api.jikan.moe": .milliseconds(400)
    ]

    public init() {}

    public func waitIfNeeded(for host: String?) async {
        guard let host = host?.lowercased(),
              let minInterval = minimumIntervals[host] else {
            return
        }

        let clock = ContinuousClock()
        let now = clock.now
        if let last = lastRequestByHost[host] {
            let elapsed = last.duration(to: now)
            if elapsed < minInterval {
                let remaining = minInterval - elapsed
                lastRequestByHost[host] = now + remaining
                try? await Task.sleep(for: remaining)
                return
            }
        }
        lastRequestByHost[host] = now
    }
}
