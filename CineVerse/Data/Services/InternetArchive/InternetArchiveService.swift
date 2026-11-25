import Foundation

public struct InternetArchiveVideoMatch: Sendable {
    public let identifier: String
    public let title: String
    public let qualities: [VideoQualityVariant]
    public let primaryPlaybackURL: URL
    public let subtitles: [SubtitleTrackOption]
    public let originalLanguage: String
    public let durationSeconds: TimeInterval?

    public init(
        identifier: String,
        title: String,
        qualities: [VideoQualityVariant],
        primaryPlaybackURL: URL,
        subtitles: [SubtitleTrackOption],
        originalLanguage: String,
        durationSeconds: TimeInterval? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.qualities = qualities
        self.primaryPlaybackURL = primaryPlaybackURL
        self.subtitles = subtitles
        self.originalLanguage = originalLanguage
        self.durationSeconds = durationSeconds
    }
}

public protocol InternetArchiveServiceProtocol: Sendable {
    func findPlayableMatch(title: String, originalTitle: String, year: Int, originalLanguage: String) async throws -> InternetArchiveVideoMatch?
    func findPlayableByIdentifier(_ identifier: String, originalLanguage: String) async throws -> InternetArchiveVideoMatch?
    func browseCatalog(category: MediaProjectType?, page: Int, limit: Int) async throws -> [MediaItem]
    func searchCatalog(query: String, page: Int, limit: Int) async throws -> [MediaItem]
    func fetchDetails(identifier: String) async throws -> MediaItem?
}

public extension InternetArchiveServiceProtocol {
    func findPlayableByIdentifier(_ identifier: String, originalLanguage: String) async throws -> InternetArchiveVideoMatch? { nil }
    func browseCatalog(category: MediaProjectType?, page: Int, limit: Int) async throws -> [MediaItem] { [] }
    func searchCatalog(query: String, page: Int, limit: Int) async throws -> [MediaItem] { [] }
    func fetchDetails(identifier: String) async throws -> MediaItem? { nil }
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
        title:("\(escapedTitle)") AND mediatype:(movies) AND (collection:(feature_films OR classic_cartoons OR classic_tv OR prelinger OR publicdomainmovies OR opensource_movies OR short_films OR silent_films OR documentaries) OR licenseurl:(*publicdomain* OR *creativecommons*))
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
            timeoutInterval: 4.5
        )

        let searchResult = try await httpClient.send(searchEndpoint, as: IAArchiveSearchResponseDTO.self)
        let normalizedTitle = title.normalizedForComparison
        let normalizedOriginal = originalTitle.normalizedForComparison

        guard let doc = searchResult.response.docs.first(where: { doc in
            let docTitle = doc.title?.stringValue.normalizedForComparison ?? ""
            let titleMatches = docTitle == normalizedTitle || docTitle == normalizedOriginal
                || (!normalizedTitle.isEmpty && docTitle.contains(normalizedTitle))
            guard titleMatches else { return false }
            if year > 0, let docYear = doc.year?.intValue {
                return abs(docYear - year) <= 1
            }
            return true
        }) else {
            return nil
        }

        return try await findPlayableByIdentifier(doc.identifier, originalLanguage: originalLanguage)
    }

    public func findPlayableByIdentifier(
        _ identifier: String,
        originalLanguage: String
    ) async throws -> InternetArchiveVideoMatch? {
        let cleanID = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty else { return nil }

        let metadataEndpoint = Endpoint(
            baseURL: baseURL,
            path: "metadata/\(cleanID)",
            timeoutInterval: 5.0
        )
        let metadata = try await httpClient.send(metadataEndpoint, as: IAMetadataResponseDTO.self)
        let files = metadata.files ?? []

        let supportedFormats: Set<String> = ["h.264", "h.264 ia", "mpeg4", "512kb mpeg4"]
        let videoFiles = files.filter { file in
            let lowerName = file.name.lowercased()
            guard !lowerName.contains("trailer") && !lowerName.contains("sample_clip") else { return false }
            let fmt = file.format?.lowercased() ?? ""
            return supportedFormats.contains(fmt) || lowerName.hasSuffix(".mp4") || lowerName.hasSuffix(".m4v")
        }

        var variantsByTier: [VideoQualityTier: VideoQualityVariant] = [:]
        var maxDurationSeconds: TimeInterval?

        for file in videoFiles {
            guard let url = downloadURL(identifier: cleanID, fileName: file.name) else { continue }
            if let lenSec = Self.parseRuntimeSeconds(file.length?.stringValue), lenSec > (maxDurationSeconds ?? 0) {
                maxDurationSeconds = lenSec
            }
            let tier: VideoQualityTier
            if let h = file.height?.intValue, h > 0 {
                tier = VideoQualityTier.from(height: h)
            } else if file.format?.lowercased().contains("512kb") == true {
                tier = .p360
            } else {
                tier = .p480
            }
            let variant = VideoQualityVariant(
                id: "ia-\(cleanID)-\(tier.rawValue)",
                tier: tier,
                width: file.width?.intValue,
                height: file.height?.intValue,
                variantStreamURL: url,
                variantFormat: .mp4
            )
            if let existing = variantsByTier[tier] {
                if (variant.height ?? 0) > (existing.height ?? 0) {
                    variantsByTier[tier] = variant
                }
            } else {
                variantsByTier[tier] = variant
            }
        }

        let sortedVariants = variantsByTier.values.sorted {
            $0.tier.resolutionPriorityRank > $1.tier.resolutionPriorityRank
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
            guard let url = downloadURL(identifier: cleanID, fileName: file.name) else { return nil }
            let langCode = originalLanguage.nilIfEmpty ?? "en"
            return SubtitleTrackOption(
                id: "ia-sub-\(file.name)",
                languageCode: langCode,
                displayName: LanguageCatalog.displayName(forLanguageCode: langCode),
                format: format,
                externalURL: url
            )
        }

        let resolvedTitle = metadata.metadata?.title?.stringValue.nilIfEmpty ?? cleanID
        let runtimeSec = maxDurationSeconds ?? Self.parseRuntimeSeconds(metadata.metadata?.runtime?.stringValue)

        return InternetArchiveVideoMatch(
            identifier: cleanID,
            title: resolvedTitle,
            qualities: sortedVariants,
            primaryPlaybackURL: primaryURL,
            subtitles: subtitles,
            originalLanguage: originalLanguage.nilIfEmpty ?? "en",
            durationSeconds: runtimeSec
        )
    }

    public func browseCatalog(category: MediaProjectType?, page: Int, limit: Int) async throws -> [MediaItem] {
        let collectionClause: String
        switch category {
        case .shortFilm:
            collectionClause = "collection:(short_films OR prelinger OR opensource_movies)"
        case .indieFestival:
            collectionClause = "collection:(opensource_movies OR feature_films OR short_films)"
        case .cartoonMovie:
            collectionClause = "collection:(classic_cartoons)"
        case .cartoonSeries:
            collectionClause = "collection:(classic_cartoons OR classic_tv)"
        case .documentary:
            collectionClause = "collection:(documentaries OR newsandpublicaffairs)"
        case .tvSeries:
            collectionClause = "collection:(classic_tv)"
        default:
            collectionClause = "collection:(feature_films OR publicdomainmovies OR silent_films OR opensource_movies OR short_films)"
        }

        let query = "mediatype:(movies) AND \(collectionClause) AND format:(h.264* OR MPEG4)"
        return try await executeCatalogSearch(q: query, sort: "downloads desc", page: page, limit: limit, forcedType: category)
    }

    public func searchCatalog(query: String, page: Int, limit: Int) async throws -> [MediaItem] {
        let escaped = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        guard !escaped.isEmpty else { return [] }
        let q = "(title:(\"\(escaped)\") OR subject:(\"\(escaped)\") OR creator:(\"\(escaped)\")) AND mediatype:(movies) AND format:(h.264* OR MPEG4)"
        return try await executeCatalogSearch(q: q, sort: "downloads desc", page: page, limit: limit, forcedType: nil)
    }

    public func fetchDetails(identifier: String) async throws -> MediaItem? {
        let cleanID = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty else { return nil }

        let ep = Endpoint(baseURL: baseURL, path: "metadata/\(cleanID)", timeoutInterval: 6.0)
        let metadata = try await httpClient.send(ep, as: IAMetadataResponseDTO.self)
        guard let meta = metadata.metadata else { return nil }

        let title = meta.title?.stringValue.nilIfEmpty ?? cleanID
        let rawDesc = meta.description?.stringValue.strippedHTML.nilIfEmpty
            ?? "Public domain / Creative Commons release hosted by Internet Archive."
        let creator = meta.creator?.stringValue.nilIfEmpty ?? "Independent / Archive Release"
        let year = meta.year?.intValue ?? Self.extractYear(from: meta.date?.stringValue) ?? 1960
        let collections = meta.collection?.stringListValue ?? []
        let subjects = meta.subject?.stringListValue ?? []
        let runtimeMin = max(1, Int(((Self.parseRuntimeSeconds(meta.runtime?.stringValue) ?? 0) / 60.0).rounded()))
        let inferredType = Self.inferProjectType(collections: collections, subjects: subjects, runtimeMinutes: runtimeMin)
        let lang = Self.normalizeLanguageCode(meta.language?.stringListValue.first)

        return MediaItem(
            id: "archive:\(inferredType.isEpisodic ? "tv" : "movie"):\(cleanID)",
            externalIDs: [.internetArchive: cleanID],
            primarySource: .internetArchive,
            projectType: inferredType,
            localizedTitle: title,
            originalTitle: title,
            synopsis: rawDesc,
            releaseYear: year,
            countryOfOrigin: "US",
            originalLanguage: lang,
            ageRating: "NR",
            genres: Array(subjects.prefix(4)).isEmpty ? ["Public Domain", inferredType.displayName] : Array(subjects.prefix(4)),
            durationMinutes: runtimeMin > 0 ? runtimeMin : (inferredType == .shortFilm ? 18 : 85),
            releaseStatus: .finished,
            ratings: MultiSourceRatings(),
            popularityScore: 420,
            posterURL: URL(string: "https://archive.org/services/img/\(cleanID)"),
            backdropURL: URL(string: "https://archive.org/services/img/\(cleanID)"),
            director: creator
        )
    }

    private func executeCatalogSearch(
        q: String,
        sort: String,
        page: Int,
        limit: Int,
        forcedType: MediaProjectType?
    ) async throws -> [MediaItem] {
        let ep = Endpoint(
            baseURL: baseURL,
            path: "advancedsearch.php",
            queryItems: [
                URLQueryItem(name: "q", value: q),
                URLQueryItem(name: "fl[]", value: "identifier"),
                URLQueryItem(name: "fl[]", value: "title"),
                URLQueryItem(name: "fl[]", value: "year"),
                URLQueryItem(name: "fl[]", value: "description"),
                URLQueryItem(name: "fl[]", value: "creator"),
                URLQueryItem(name: "fl[]", value: "subject"),
                URLQueryItem(name: "fl[]", value: "collection"),
                URLQueryItem(name: "fl[]", value: "runtime"),
                URLQueryItem(name: "fl[]", value: "language"),
                URLQueryItem(name: "fl[]", value: "downloads"),
                URLQueryItem(name: "sort[]", value: sort),
                URLQueryItem(name: "page", value: String(max(page, 1))),
                URLQueryItem(name: "rows", value: String(min(max(limit, 1), 40))),
                URLQueryItem(name: "output", value: "json")
            ],
            timeoutInterval: 6.5
        )
        let response = try await httpClient.send(ep, as: IAArchiveSearchResponseDTO.self)
        return response.response.docs.compactMap { doc in
            mapSearchDoc(doc, forcedType: forcedType)
        }
    }

    private func mapSearchDoc(_ doc: IAArchiveSearchDocDTO, forcedType: MediaProjectType?) -> MediaItem? {
        guard let title = doc.title?.stringValue.nilIfEmpty else { return nil }
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("trailer") || lowerTitle.contains("teaser") {
            return nil
        }
        let collections = doc.collection?.stringListValue ?? []
        let subjects = doc.subject?.stringListValue ?? []
        let runtimeSec = Self.parseRuntimeSeconds(doc.runtime?.stringValue)
        let runtimeMin = runtimeSec.map { max(1, Int(($0 / 60.0).rounded())) } ?? 0
        let projectType = forcedType ?? Self.inferProjectType(collections: collections, subjects: subjects, runtimeMinutes: runtimeMin)
        let downloads = doc.downloads?.intValue ?? 100
        let popScore = min(900.0, max(120.0, log10(Double(max(downloads, 10))) * 120.0))
        let year = doc.year?.intValue ?? 0
        let lang = Self.normalizeLanguageCode(doc.language?.stringListValue.first)

        return MediaItem(
            id: "archive:\(projectType.isEpisodic ? "tv" : "movie"):\(doc.identifier)",
            externalIDs: [.internetArchive: doc.identifier],
            primarySource: .internetArchive,
            projectType: projectType,
            localizedTitle: title,
            originalTitle: title,
            synopsis: doc.description?.stringValue.strippedHTML.nilIfEmpty ?? "Public domain & Creative Commons archive release.",
            releaseYear: year,
            countryOfOrigin: "US",
            originalLanguage: lang,
            ageRating: "NR",
            genres: Array(subjects.prefix(3)).isEmpty ? ["Public Domain", projectType.displayName] : Array(subjects.prefix(3)),
            durationMinutes: runtimeMin > 0 ? runtimeMin : (projectType == .shortFilm ? 15 : 75),
            releaseStatus: .finished,
            ratings: MultiSourceRatings(),
            popularityScore: popScore,
            posterURL: URL(string: "https://archive.org/services/img/\(doc.identifier)"),
            backdropURL: URL(string: "https://archive.org/services/img/\(doc.identifier)"),
            director: doc.creator?.stringValue.nilIfEmpty ?? "Internet Archive"
        )
    }

    private func downloadURL(identifier: String, fileName: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "archive.org"
        components.path = "/download/\(identifier)/\(fileName)"
        return components.url
    }

    public static func inferProjectType(collections: [String], subjects: [String], runtimeMinutes: Int) -> MediaProjectType {
        let joined = (collections + subjects).joined(separator: " ").lowercased()
        if joined.contains("classic_tv") || joined.contains("television") {
            return joined.contains("cartoon") ? .cartoonSeries : .tvSeries
        }
        if joined.contains("cartoon") || joined.contains("animation") {
            return .cartoonMovie
        }
        if joined.contains("documentar") || joined.contains("newsandpublicaffairs") {
            return .documentary
        }
        if joined.contains("short_films") || (runtimeMinutes > 0 && runtimeMinutes <= 42) {
            return .shortFilm
        }
        if joined.contains("opensource_movies") || joined.contains("indie") || joined.contains("festival") {
            return .indieFestival
        }
        return .movie
    }

    public static func parseRuntimeSeconds(_ raw: String?) -> TimeInterval? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.contains(":") {
            let parts = raw.split(separator: ":").compactMap { Double($0) }
            if parts.count == 3 {
                return parts[0] * 3600 + parts[1] * 60 + parts[2]
            } else if parts.count == 2 {
                return parts[0] * 60 + parts[1]
            }
        }
        if let numeric = Double(raw), numeric > 0 {
            return numeric
        }
        let lower = raw.lowercased()
        if lower.hasSuffix("m"), let mins = Double(lower.dropLast().trimmingCharacters(in: .whitespaces)) {
            return mins * 60
        }
        return nil
    }

    private static func extractYear(from text: String?) -> Int? {
        guard let text, text.count >= 4 else { return nil }
        return Int(text.prefix(4))
    }

    private static func normalizeLanguageCode(_ raw: String?) -> String {
        guard let lower = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !lower.isEmpty else {
            return "en"
        }
        if lower.count == 2 { return lower }
        if lower.contains("rus") { return "ru" }
        if lower.contains("fre") || lower.contains("fra") { return "fr" }
        if lower.contains("ger") || lower.contains("deu") { return "de" }
        if lower.contains("spa") { return "es" }
        if lower.contains("jpn") || lower.contains("jap") { return "ja" }
        if lower.contains("kor") { return "ko" }
        return "en"
    }
}
