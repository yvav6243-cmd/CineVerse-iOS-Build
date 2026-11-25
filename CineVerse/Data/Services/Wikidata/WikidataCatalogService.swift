import Foundation

public protocol WikidataCatalogServiceProtocol: Sendable {
    func searchTitles(query: String, language: String, limit: Int) async throws -> [MediaItem]
    func fetchDetails(entityID: String, language: String) async throws -> MediaItem?
}

public extension WikidataCatalogServiceProtocol {
    func searchTitles(query: String, language: String, limit: Int) async throws -> [MediaItem] { [] }
    func fetchDetails(entityID: String, language: String) async throws -> MediaItem? { nil }
}

public final class WikidataCatalogService: WikidataCatalogServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://www.wikidata.org")
    private let wikiSummaryBaseURL = URL.constant("https://en.wikipedia.org")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func searchTitles(query: String, language: String, limit: Int = 12) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let langCode = String(language.prefix(2)).lowercased().nilIfEmpty ?? "en"
        let searchEp = Endpoint(
            baseURL: baseURL,
            path: "w/api.php",
            queryItems: [
                URLQueryItem(name: "action", value: "wbsearchentities"),
                URLQueryItem(name: "search", value: trimmed),
                URLQueryItem(name: "language", value: langCode),
                URLQueryItem(name: "uselang", value: langCode),
                URLQueryItem(name: "type", value: "item"),
                URLQueryItem(name: "limit", value: String(min(max(limit, 4), 20))),
                URLQueryItem(name: "format", value: "json")
            ],
            headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
            timeoutInterval: 5.5
        )
        let searchDTO = try await httpClient.send(searchEp, as: WikidataSearchResponseDTO.self)
        let candidateIDs = (searchDTO.search ?? [])
            .filter { WikidataMapper.isLikelyMediaDescription($0.description) }
            .map(\.id)
        guard !candidateIDs.isEmpty else { return [] }

        let idsParam = candidateIDs.prefix(12).joined(separator: "|")
        let entitiesEp = Endpoint(
            baseURL: baseURL,
            path: "w/api.php",
            queryItems: [
                URLQueryItem(name: "action", value: "wbgetentities"),
                URLQueryItem(name: "ids", value: idsParam),
                URLQueryItem(name: "props", value: "labels|descriptions|aliases|claims|sitelinks"),
                URLQueryItem(name: "languages", value: "\(langCode)|en"),
                URLQueryItem(name: "format", value: "json")
            ],
            headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
            timeoutInterval: 6.0
        )
        let entitiesDTO = try await httpClient.send(entitiesEp, as: WikidataEntitiesResponseDTO.self)
        let dict = entitiesDTO.entities ?? [:]
        return candidateIDs.compactMap { qid in
            guard let entity = dict[qid] else { return nil }
            return WikidataMapper.mapEntity(entity, preferredLanguage: langCode)
        }
    }

    public func fetchDetails(entityID: String, language: String) async throws -> MediaItem? {
        let cleanQID = entityID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanQID.hasPrefix("Q") else { return nil }
        let langCode = String(language.prefix(2)).lowercased().nilIfEmpty ?? "en"

        let entitiesEp = Endpoint(
            baseURL: baseURL,
            path: "w/api.php",
            queryItems: [
                URLQueryItem(name: "action", value: "wbgetentities"),
                URLQueryItem(name: "ids", value: cleanQID),
                URLQueryItem(name: "props", value: "labels|descriptions|aliases|claims|sitelinks"),
                URLQueryItem(name: "languages", value: "\(langCode)|en"),
                URLQueryItem(name: "format", value: "json")
            ],
            headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
            timeoutInterval: 6.0
        )
        let response = try await httpClient.send(entitiesEp, as: WikidataEntitiesResponseDTO.self)
        guard let entity = response.entities?[cleanQID],
              let mapped = WikidataMapper.mapEntity(entity, preferredLanguage: langCode) else {
            return nil
        }

        if let wikiTitle = entity.sitelinks?["enwiki"]?.title?.nilIfEmpty {
            let encodedTitle = wikiTitle.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? wikiTitle
            let summaryEp = Endpoint(
                baseURL: wikiSummaryBaseURL,
                path: "api/rest_v1/page/summary/\(encodedTitle)",
                headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
                timeoutInterval: 4.5
            )
            if let summary = try? await httpClient.send(summaryEp, as: WikipediaSummaryDTO.self) {
                let enrichedSynopsis = summary.extract?.nilIfEmpty ?? mapped.synopsis
                let enrichedPoster = mapped.posterURL ?? summary.thumbnail?.source.flatMap(URL.init(string:))
                return MediaItem(
                    id: mapped.id,
                    externalIDs: mapped.externalIDs,
                    primarySource: .wikidata,
                    projectType: mapped.projectType,
                    localizedTitle: mapped.localizedTitle,
                    originalTitle: mapped.originalTitle,
                    synopsis: enrichedSynopsis,
                    releaseYear: mapped.releaseYear,
                    releaseDate: mapped.releaseDate,
                    countryOfOrigin: mapped.countryOfOrigin,
                    originalLanguage: mapped.originalLanguage,
                    ageRating: mapped.ageRating,
                    genres: mapped.genres,
                    durationMinutes: mapped.durationMinutes,
                    releaseStatus: mapped.releaseStatus,
                    ratings: mapped.ratings,
                    popularityScore: mapped.popularityScore,
                    posterURL: enrichedPoster,
                    backdropURL: enrichedPoster,
                    director: mapped.director,
                    alternativeTitles: mapped.alternativeTitles
                )
            }
        }
        return mapped
    }
}

public enum WikidataMapper {
    private static let mediaKeywords = [
        "film", "movie", "series", "television", "tv", "anime", "ova",
        "drama", "documentary", "short", "animated", "animation", "miniseries",
        "feature", "cinema", "web series", "фильм", "сериал", "аниме", "мультфильм"
    ]

    public static func isLikelyMediaDescription(_ raw: String?) -> Bool {
        guard let lower = raw?.lowercased(), !lower.isEmpty else { return false }
        if lower.contains("soundtrack") || lower.contains("film director") || lower.contains("actor") || lower.contains("actress") {
            return false
        }
        return mediaKeywords.contains { lower.contains($0) }
    }

    public static func mapEntity(_ entity: WikidataEntityDTO, preferredLanguage: String) -> MediaItem? {
        let title = entity.labels?[preferredLanguage]?.value
            ?? entity.labels?["en"]?.value
            ?? entity.labels?.values.first?.value
            ?? ""
        guard !title.isEmpty else { return nil }

        let origTitle = entity.labels?["en"]?.value ?? title
        let desc = entity.descriptions?[preferredLanguage]?.value
            ?? entity.descriptions?["en"]?.value
            ?? ""
        guard desc.isEmpty || isLikelyMediaDescription(desc) else { return nil }

        let lowerDesc = desc.lowercased()
        let projectType: MediaProjectType = {
            if lowerDesc.contains("anime") { return lowerDesc.contains("film") ? .animeMovie : .anime }
            if lowerDesc.contains("documentary") { return .documentary }
            if lowerDesc.contains("short film") || lowerDesc.contains("short") { return .shortFilm }
            if lowerDesc.contains("animated") && (lowerDesc.contains("series") || lowerDesc.contains("television")) { return .cartoonSeries }
            if lowerDesc.contains("animated") { return .cartoonMovie }
            if lowerDesc.contains("miniseries") || lowerDesc.contains("television series") || lowerDesc.contains("tv series") || lowerDesc.contains("сериал") {
                return .tvSeries
            }
            if lowerDesc.contains("drama") { return .drama }
            if lowerDesc.contains("independent") || lowerDesc.contains("festival") { return .indieFestival }
            return .movie
        }()

        let releaseDate = extractPublicationDate(claims: entity.claims?["P577"])
        let now = Date()
        let releaseYear: Int = {
            if let releaseDate {
                return Calendar.current.component(.year, from: releaseDate)
            }
            return extractYear(from: desc) ?? 0
        }()
        let status: MediaReleaseStatus = (releaseDate != nil && (releaseDate ?? .distantPast) > now) ? .upcoming : .finished

        var externalIDs: [MetadataProviderSource: String] = [.wikidata: entity.id]
        if let iaID = entity.claims?["P724"]?.first?.mainsnak?.datavalue?.stringValue?.nilIfEmpty {
            externalIDs[.internetArchive] = iaID
        }

        let posterURL: URL? = {
            guard let fileName = entity.claims?["P18"]?.first?.mainsnak?.datavalue?.stringValue?.nilIfEmpty else { return nil }
            let escaped = fileName.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
            return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(escaped)?width=500")
        }()

        let runtimeMin = entity.claims?["P2047"]?.first?.mainsnak?.datavalue?.amountIntValue ?? 0
        let aliases = (entity.aliases?["en"] ?? []).map(\.value)

        return MediaItem(
            id: "wikidata:\(projectType.isEpisodic ? "tv" : "movie"):\(entity.id)",
            externalIDs: externalIDs,
            primarySource: .wikidata,
            projectType: projectType,
            localizedTitle: title,
            originalTitle: origTitle,
            synopsis: desc.nilIfEmpty ?? "Global catalog entry via Wikidata.",
            releaseYear: releaseYear,
            releaseDate: releaseDate,
            countryOfOrigin: "UN",
            originalLanguage: preferredLanguage,
            ageRating: "NR",
            genres: [projectType.displayName],
            durationMinutes: runtimeMin > 0 ? runtimeMin : (projectType == .shortFilm ? 18 : 90),
            releaseStatus: status,
            ratings: MultiSourceRatings(),
            popularityScore: status == .upcoming ? 260 : 210,
            posterURL: posterURL,
            backdropURL: posterURL,
            director: "Unknown Director",
            alternativeTitles: aliases
        )
    }

    private static func extractPublicationDate(claims: [WikidataClaimDTO]?) -> Date? {
        guard let rawTime = claims?.first?.mainsnak?.datavalue?.timeStringValue else { return nil }
        // Format: +2026-07-15T00:00:00Z or +2026-00-00T00:00:00Z
        let cleaned = rawTime.hasPrefix("+") ? String(rawTime.dropFirst()) : rawTime
        let datePart = String(cleaned.prefix(10))
            .replacingOccurrences(of: "-00", with: "-01")
        return CineVerseDateFormatters.isoDateParser.date(from: datePart)
    }

    private static func extractYear(from text: String) -> Int? {
        let tokens = text.split(separator: " ")
        for tok in tokens {
            let digits = tok.filter(\.isNumber)
            if digits.count == 4, let yr = Int(digits), (1895...2035).contains(yr) {
                return yr
            }
        }
        return nil
    }
}

public struct WikidataSearchResponseDTO: Decodable, Sendable {
    public let search: [WikidataSearchEntryDTO]?
}

public struct WikidataSearchEntryDTO: Decodable, Sendable {
    public let id: String
    public let label: String?
    public let description: String?
}

public struct WikidataEntitiesResponseDTO: Decodable, Sendable {
    public let entities: [String: WikidataEntityDTO]?
}

public struct WikidataEntityDTO: Decodable, Sendable {
    public let id: String
    public let labels: [String: WikidataTextValueDTO]?
    public let descriptions: [String: WikidataTextValueDTO]?
    public let aliases: [String: [WikidataTextValueDTO]]?
    public let claims: [String: [WikidataClaimDTO]]?
    public let sitelinks: [String: WikidataSitelinkDTO]?
}

public struct WikidataTextValueDTO: Decodable, Sendable {
    public let value: String
}

public struct WikidataSitelinkDTO: Decodable, Sendable {
    public let title: String?
}

public struct WikidataClaimDTO: Decodable, Sendable {
    public let mainsnak: WikidataSnakDTO?
}

public struct WikidataSnakDTO: Decodable, Sendable {
    public let datavalue: WikidataDataValueDTO?
}

public struct WikidataDataValueDTO: Decodable, Sendable {
    public let type: String?
    public let stringValue: String?
    public let timeStringValue: String?
    public let amountIntValue: Int?

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    private struct TimeValuePayload: Decodable { let time: String? }
    private struct QuantityPayload: Decodable { let amount: String? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try? c.decode(String.self, forKey: .type)
        stringValue = try? c.decode(String.self, forKey: .value)
        if let tv = try? c.decode(TimeValuePayload.self, forKey: .value) {
            timeStringValue = tv.time
        } else {
            timeStringValue = nil
        }
        if let qv = try? c.decode(QuantityPayload.self, forKey: .value), let amt = qv.amount {
            let trimmed = amt.hasPrefix("+") ? String(amt.dropFirst()) : amt
            amountIntValue = Int(Double(trimmed) ?? 0)
        } else {
            amountIntValue = nil
        }
    }
}

public struct WikipediaSummaryDTO: Decodable, Sendable {
    public let extract: String?
    public let thumbnail: WikipediaThumbnailDTO?
}

public struct WikipediaThumbnailDTO: Decodable, Sendable {
    public let source: String?
}
