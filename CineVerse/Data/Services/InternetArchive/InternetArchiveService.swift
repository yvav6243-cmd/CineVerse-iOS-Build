import Foundation

public struct InternetArchiveVideoMatch: Sendable {
    public let identifier: String
    public let title: String
    public let qualities: [VideoQualityVariant]
    public let primaryPlaybackURL: URL
    public let subtitles: [SubtitleTrackOption]
    public let originalLanguage: String
}

public protocol InternetArchiveServiceProtocol: Sendable {
    func findPlayableMatch(title: String, originalTitle: String, year: Int, originalLanguage: String) async throws -> InternetArchiveVideoMatch?
}

public final class InternetArchiveService: InternetArchiveServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://archive.org")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func findPlayableMatch(
        title: String,
        originalTitle: String,
        year: Int,
        originalLanguage: String
    ) async throws -> InternetArchiveVideoMatch? {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "")
        guard !escapedTitle.isEmpty else { return nil }

        let query = """
        title:("\(escapedTitle)") AND mediatype:(movies) AND (collection:(feature_films OR classic_cartoons OR classic_tv OR prelinger OR publicdomainmovies) OR licenseurl:(*publicdomain* OR *creativecommons*))
        """
        let searchEndpoint = Endpoint(
            baseURL: baseURL,
            path: "advancedsearch.php",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "fl[]", value: "identifier"),
                URLQueryItem(name: "fl[]", value: "title"),
                URLQueryItem(name: "fl[]", value: "year"),
                URLQueryItem(name: "rows", value: "8"),
                URLQueryItem(name: "output", value: "json")
            ],
            timeoutInterval: 3.5
        )

        let searchResult = try await httpClient.send(searchEndpoint, as: IAArchiveSearchResponseDTO.self)
        let normalizedTitle = title.normalizedForComparison
        let normalizedOriginal = originalTitle.normalizedForComparison

        guard let doc = searchResult.response.docs.first(where: { doc in
            let docTitle = doc.title?.stringValue.normalizedForComparison ?? ""
            let titleMatches = docTitle == normalizedTitle || docTitle == normalizedOriginal
            guard titleMatches else { return false }
            if year > 0, let docYear = doc.year?.intValue {
                return abs(docYear - year) <= 1
            }
            return true
        }) else {
            return nil
        }

        let metadataEndpoint = Endpoint(
            baseURL: baseURL,
            path: "metadata/\(doc.identifier)",
            timeoutInterval: 3.5
        )
        let metadata = try await httpClient.send(metadataEndpoint, as: IAMetadataResponseDTO.self)
        let files = metadata.files ?? []

        let supportedFormats: Set<String> = ["h.264", "h.264 ia", "mpeg4", "512kb mpeg4"]
        let videoFiles = files.filter { file in
            let fmt = file.format?.lowercased() ?? ""
            return supportedFormats.contains(fmt) || file.name.lowercased().hasSuffix(".mp4")
        }

        var variantsByTier: [VideoQualityTier: VideoQualityVariant] = [:]
        for file in videoFiles {
            guard let url = downloadURL(identifier: doc.identifier, fileName: file.name) else { continue }
            let tier: VideoQualityTier
            if let h = file.height?.intValue, h > 0 {
                tier = VideoQualityTier.from(height: h)
            } else if file.format?.lowercased().contains("512kb") == true {
                tier = .p360
            } else {
                tier = .p480
            }
            let variant = VideoQualityVariant(
                id: "ia-\(doc.identifier)-\(tier.rawValue)",
                tier: tier,
                width: file.width?.intValue,
                height: file.height?.intValue,
                variantStreamURL: url
            )
            if variantsByTier[tier] == nil {
                variantsByTier[tier] = variant
            }
        }

        let sortedVariants = variantsByTier.values.sorted {
            ($0.height ?? 0) > ($1.height ?? 0)
        }
        guard let primaryURL = sortedVariants.first?.variantStreamURL else {
            return nil
        }

        let subtitles: [SubtitleTrackOption] = files.compactMap { file in
            let lower = file.name.lowercased()
            let format: SubtitleFormat
            if lower.hasSuffix(".vtt") {
                format = .webVTT
            } else if lower.hasSuffix(".srt") {
                format = .srt
            } else {
                return nil
            }
            guard let url = downloadURL(identifier: doc.identifier, fileName: file.name) else { return nil }
            let langCode = originalLanguage.nilIfEmpty ?? "en"
            return SubtitleTrackOption(
                id: "ia-sub-\(file.name)",
                languageCode: langCode,
                displayName: LanguageCatalog.displayName(forLanguageCode: langCode),
                format: format,
                externalURL: url
            )
        }

        return InternetArchiveVideoMatch(
            identifier: doc.identifier,
            title: doc.title?.stringValue ?? title,
            qualities: sortedVariants,
            primaryPlaybackURL: primaryURL,
            subtitles: subtitles,
            originalLanguage: originalLanguage
        )
    }

    private func downloadURL(identifier: String, fileName: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "archive.org"
        components.path = "/download/\(identifier)/\(fileName)"
        return components.url
    }
}
