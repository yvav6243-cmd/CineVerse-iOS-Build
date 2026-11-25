import Foundation

public actor SourceHealthChecker {
    private struct CachedHealth: Sendable {
        let status: SourceHealthStatus
        let checkedAt: Date
    }

    private let httpClient: HTTPClient
    private var cache: [String: CachedHealth] = [:]
    private let ttlSeconds: TimeInterval = 15 * 60

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func check(_ descriptor: VideoSourceDescriptor) async -> VideoSourceDescriptor {
        guard descriptor.isAvailable else {
            var copy = descriptor
            copy.healthStatus = .offline(reason: "Source unavailable")
            return copy
        }

        switch descriptor.format {
        case .localFile:
            var copy = descriptor
            if let url = descriptor.playbackURL, FileManager.default.fileExists(atPath: url.path) {
                copy.healthStatus = .online(latencyMs: 1)
                copy.isAvailable = true
            } else {
                copy.healthStatus = .offline(reason: "Local file missing")
                copy.isAvailable = false
            }
            return copy

        case .externalOfficialService:
            return descriptor

        case .hls, .mp4, .webm, .dash:
            guard let url = descriptor.playbackURL else {
                var copy = descriptor
                copy.isAvailable = false
                copy.healthStatus = .offline(reason: "Missing stream URL")
                return copy
            }

            let key = url.absoluteString
            if let existing = cache[key], Date().timeIntervalSince(existing.checkedAt) < ttlSeconds {
                var copy = descriptor
                copy.healthStatus = existing.status
                if case .offline = existing.status {
                    copy.isAvailable = false
                }
                return copy
            }

            let start = ContinuousClock.now
            let status = await probeURL(url)
            let elapsed = start.duration(to: ContinuousClock.now)
            let latencyMs = max(1, Int(Double(elapsed.components.seconds) * 1000.0 + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0))

            let finalStatus: SourceHealthStatus
            switch status {
            case .online:
                finalStatus = .online(latencyMs: latencyMs)
            case .offline(let reason):
                finalStatus = .offline(reason: reason)
            default:
                finalStatus = status
            }

            cache[key] = CachedHealth(status: finalStatus, checkedAt: Date())
            var updated = descriptor
            updated.healthStatus = finalStatus
            if case .offline = finalStatus {
                updated.isAvailable = false
            }
            return updated
        }
    }

    private func probeURL(_ url: URL) async -> SourceHealthStatus {
        let headEndpoint = Endpoint(
            baseURL: url,
            path: "",
            method: .head,
            headers: ["User-Agent": "CineVerse-iOS/2.0"],
            timeoutInterval: 5
        )
        if let (_, resp) = try? await httpClient.data(headEndpoint),
           (200...399).contains(resp.statusCode) {
            return .online(latencyMs: 0)
        }

        let rangeEndpoint = Endpoint(
            baseURL: url,
            path: "",
            method: .get,
            headers: [
                "Range": "bytes=0-1023",
                "User-Agent": "CineVerse-iOS/2.0"
            ],
            timeoutInterval: 6
        )
        do {
            let (_, resp) = try await httpClient.data(rangeEndpoint)
            if (200...399).contains(resp.statusCode) {
                return .online(latencyMs: 0)
            }
            return .offline(reason: "HTTP \(resp.statusCode)")
        } catch {
            return .offline(reason: "Unreachable")
        }
    }
}
