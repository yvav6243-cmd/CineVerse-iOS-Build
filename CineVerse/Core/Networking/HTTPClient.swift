import Foundation

public protocol HTTPClient: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func data(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse)
}

public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let decoder: JSONDecoder

    public init(
        rateLimiter: RateLimiter = RateLimiter(),
        sessionConfiguration: URLSessionConfiguration? = nil
    ) {
        let config = sessionConfiguration ?? {
            let cfg = URLSessionConfiguration.default
            cfg.urlCache = URLCache(
                memoryCapacity: 20 * 1024 * 1024,
                diskCapacity: 150 * 1024 * 1024
            )
            cfg.timeoutIntervalForRequest = 20
            cfg.waitsForConnectivity = false
            return cfg
        }()
        self.session = URLSession(configuration: config)
        self.rateLimiter = rateLimiter
        self.decoder = JSONDecoder()
    }

    public func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let (data, _) = try await self.data(endpoint)
        do {
            return try decoder.decode(type, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decoding(Self.describe(decodingError))
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }

    public func data(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let request = try endpoint.makeRequest()
        let maxRetries = 2
        let backoffDelays: [TimeInterval] = [0.8, 1.6]

        for attempt in 0...maxRetries {
            if Task.isCancelled {
                throw NetworkError.cancelled
            }
            await rateLimiter.waitIfNeeded(for: request.url?.host)

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.http(statusCode: -1, message: "Invalid HTTP response")
                }

                let status = httpResponse.statusCode
                if (200...299).contains(status) {
                    return (data, httpResponse)
                }

                if status == 429 || (500...599).contains(status) {
                    let retryAfter = Self.parseRetryAfter(httpResponse)
                    if attempt < maxRetries {
                        let delay = retryAfter ?? backoffDelays[min(attempt, backoffDelays.count - 1)]
                        try await Task.sleep(for: .seconds(min(delay, 10)))
                        continue
                    }
                    if status == 429 {
                        throw NetworkError.rateLimited(retryAfterSeconds: retryAfter)
                    }
                    throw NetworkError.http(
                        statusCode: status,
                        message: Self.extractServerMessage(from: data)
                    )
                }

                throw NetworkError.http(
                    statusCode: status,
                    message: Self.extractServerMessage(from: data)
                )
            } catch let error as NetworkError {
                throw error
            } catch is CancellationError {
                throw NetworkError.cancelled
            } catch let urlError as URLError {
                switch urlError.code {
                case .cancelled:
                    throw NetworkError.cancelled
                case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                     .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    throw NetworkError.offline
                default:
                    throw NetworkError.http(statusCode: urlError.errorCode, message: urlError.localizedDescription)
                }
            } catch {
                throw NetworkError.http(statusCode: -1, message: error.localizedDescription)
            }
        }

        throw NetworkError.http(statusCode: -1, message: "Request exhausted retries")
    }

    private static func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return max(0.5, seconds)
    }

    private static func extractServerMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let msg = json["status_message"] as? String { return msg }
        if let msg = json["message"] as? String { return msg }
        if let errors = json["errors"] as? [[String: Any]],
           let first = errors.first?["message"] as? String {
            return first
        }
        return nil
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing key '\(key.stringValue)'"
        case .typeMismatch(let type, let ctx):
            return "Type mismatch for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let ctx):
            return "Null value for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let ctx):
            return "Corrupted data: \(ctx.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
