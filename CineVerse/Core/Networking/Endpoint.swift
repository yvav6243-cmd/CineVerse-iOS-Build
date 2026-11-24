import Foundation
import CryptoKit

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case head = "HEAD"
}

public struct Endpoint: Sendable {
    public let baseURL: URL
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: Data?
    public let cachePolicy: URLRequest.CachePolicy
    public let cacheTTL: TimeInterval?
    public let timeoutInterval: TimeInterval

    public init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        cacheTTL: TimeInterval? = nil,
        timeoutInterval: TimeInterval = 20
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.cachePolicy = cachePolicy
        self.cacheTTL = cacheTTL
        self.timeoutInterval = timeoutInterval
    }

    public func makeRequest() throws -> URLRequest {
        guard baseURL.scheme?.lowercased() == "https" else {
            throw NetworkError.insecureURL
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let resolvedURL = trimmedPath.isEmpty ? baseURL : baseURL.appendingPathComponent(trimmedPath)

        guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        if !queryItems.isEmpty {
            var existing = components.queryItems ?? []
            existing.append(contentsOf: queryItems)
            components.queryItems = existing
        }

        guard let finalURL = components.url, finalURL.scheme?.lowercased() == "https" else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(
            url: finalURL,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
        request.httpMethod = method.rawValue
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    public var cacheKey: String {
        let queryString = queryItems
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        var raw = "\(method.rawValue)|\(baseURL.absoluteString)|\(path)|\(queryString)"
        if let body {
            let digest = SHA256.hash(data: body)
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            raw += "|\(hex)"
        }
        return raw
    }
}
