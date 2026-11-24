import Foundation

public enum NetworkError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case insecureURL
    case offline
    case http(statusCode: Int, message: String?)
    case rateLimited(retryAfterSeconds: TimeInterval?)
    case decoding(String)
    case cancelled
    case missingAPIKey(MetadataProviderSource)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL could not be constructed."
        case .insecureURL:
            return "Only secure HTTPS connections are permitted."
        case .offline:
            return "No internet connection. Showing cached or local library data where available."
        case .http(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server returned status code \(statusCode)."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limit reached. Please retry in \(Int(retryAfter.rounded(.up))) seconds."
            }
            return "Rate limit reached. Please try again shortly."
        case .decoding(let detail):
            return "Unable to parse response data: \(detail)"
        case .cancelled:
            return "Request was cancelled."
        case .missingAPIKey(let source):
            return "\(source.rawValue) API key is not configured. Add it in Profile → API Keys."
        }
    }
}
