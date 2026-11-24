import Foundation

public enum SourceValidationError: LocalizedError, Sendable, Equatable {
    case emptyInput
    case tooLong
    case invalidURL
    case insecureProtocol
    case privateOrLocalHost
    case embeddedCredentials
    case forbiddenFileType(String)
    case unsupportedMediaType(String)
    case unreachable(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Please enter a video URL."
        case .tooLong:
            return "URL exceeds the 2048-character safety limit."
        case .invalidURL:
            return "The entered string is not a valid URL."
        case .insecureProtocol:
            return "Only HTTPS URLs are permitted under App Transport Security."
        case .privateOrLocalHost:
            return "Localhost and private network IP addresses are not allowed for remote links."
        case .embeddedCredentials:
            return "URLs containing embedded usernames or passwords are rejected for security."
        case .forbiddenFileType(let ext):
            return "Files with extension .\(ext) are blocked as potentially unsafe."
        case .unsupportedMediaType(let detail):
            return "Unsupported stream format (\(detail)). Use .m3u8, .mp4, .m4v, or .mov."
        case .unreachable(let reason):
            return "Could not verify stream availability: \(reason)"
        }
    }
}

public struct ValidatedStreamInfo: Sendable, Equatable {
    public let url: URL
    public let detectedFormat: VideoStreamFormat
    public let contentType: String?
}

public enum SourceURLValidator {
    private static let forbiddenExtensions: Set<String> = [
        "exe", "ipa", "apk", "dmg", "pkg", "app", "sh", "bat",
        "js", "zip", "rar", "7z", "msi", "deb", "cmd", "ps1", "scr", "tar", "gz"
    ]

    private static let allowedVideoExtensions: Set<String> = ["m3u8", "mp4", "m4v", "mov"]
    private static let allowedSubtitleExtensions: Set<String> = ["srt", "vtt"]

    private static let acceptedVideoContentTypes: Set<String> = [
        "video/mp4",
        "video/quicktime",
        "video/x-m4v",
        "application/vnd.apple.mpegurl",
        "application/x-mpegurl",
        "audio/mpegurl",
        "audio/x-mpegurl"
    ]

    public static func validateSyntax(_ rawString: String) -> Result<URL, SourceValidationError> {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        guard trimmed.count <= 2048 else { return .failure(.tooLong) }

        guard let components = URLComponents(string: trimmed),
              let url = components.url else {
            return .failure(.invalidURL)
        }

        guard url.scheme?.lowercased() == "https" else {
            return .failure(.insecureProtocol)
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return .failure(.invalidURL)
        }

        if isPrivateOrLocalHost(host) {
            return .failure(.privateOrLocalHost)
        }

        if components.user != nil || components.password != nil {
            return .failure(.embeddedCredentials)
        }

        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && forbiddenExtensions.contains(ext) {
            return .failure(.forbiddenFileType(ext))
        }

        if !ext.isEmpty && !allowedVideoExtensions.contains(ext) {
            return .failure(.unsupportedMediaType(".\(ext)"))
        }

        return .success(url)
    }

    public static func validateSubtitleSyntax(_ rawString: String) -> Result<URL, SourceValidationError> {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        guard trimmed.count <= 2048 else { return .failure(.tooLong) }

        guard let components = URLComponents(string: trimmed),
              let url = components.url else {
            return .failure(.invalidURL)
        }
        guard url.scheme?.lowercased() == "https" else {
            return .failure(.insecureProtocol)
        }
        guard let host = url.host?.lowercased(), !host.isEmpty, !isPrivateOrLocalHost(host) else {
            return .failure(.privateOrLocalHost)
        }
        if components.user != nil || components.password != nil {
            return .failure(.embeddedCredentials)
        }

        let ext = url.pathExtension.lowercased()
        if forbiddenExtensions.contains(ext) {
            return .failure(.forbiddenFileType(ext))
        }
        if !ext.isEmpty && !allowedSubtitleExtensions.contains(ext) {
            return .failure(.unsupportedMediaType(".\(ext)"))
        }
        return .success(url)
    }

    public static func validateReachability(
        url: URL,
        httpClient: HTTPClient
    ) async -> Result<ValidatedStreamInfo, SourceValidationError> {
        let headEndpoint = Endpoint(baseURL: url, path: "", method: .head, timeoutInterval: 10)
        if let (_, response) = try? await httpClient.data(headEndpoint) {
            return evaluateResponse(url: url, response: response)
        }

        // Fallback to a 1KB Range GET for servers that reject HEAD requests
        let rangeEndpoint = Endpoint(
            baseURL: url,
            path: "",
            method: .get,
            headers: ["Range": "bytes=0-1023"],
            timeoutInterval: 10
        )
        do {
            let (_, response) = try await httpClient.data(rangeEndpoint)
            return evaluateResponse(url: url, response: response)
        } catch {
            return .failure(.unreachable(error.localizedDescription))
        }
    }

    private static func evaluateResponse(url: URL, response: HTTPURLResponse) -> Result<ValidatedStreamInfo, SourceValidationError> {
        let rawContentType = (response.value(forHTTPHeaderField: "Content-Type") ?? "")
            .split(separator: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" || rawContentType.contains("mpegurl") {
            return .success(ValidatedStreamInfo(url: url, detectedFormat: .hls, contentType: rawContentType))
        }
        if allowedVideoExtensions.contains(ext) || acceptedVideoContentTypes.contains(rawContentType) || rawContentType.hasPrefix("video/") {
            return .success(ValidatedStreamInfo(url: url, detectedFormat: .mp4, contentType: rawContentType))
        }
        return .failure(.unsupportedMediaType(rawContentType.isEmpty ? "unknown" : rawContentType))
    }

    public static func isPrivateOrLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" || host == "[::1]" {
            return true
        }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        let a = parts[0]
        let b = parts[1]
        if a == 127 || a == 10 || a == 0 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 169 && b == 254 { return true }
        return false
    }
}
