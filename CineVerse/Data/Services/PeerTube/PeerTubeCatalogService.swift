import Foundation

public struct PeerTubeVideoMatch: Sendable {
    public let uuid: String
    public let host: String
    public let title: String
    public let playbackURL: URL
    public let format: VideoStreamFormat
    public let durationSeconds: TimeInterval
    public let qualities: [VideoQualityVariant]
}

public protocol PeerTubeCatalogServiceProtocol: Sendable {
    func discoverOpenVideos(category: MediaProjectType?, page: Int, limit: Int) async throws -> [MediaItem]
    func findPlayableMatch(title: String, originalTitle: String, expectedDurationMinutes: Int, isShort: Bool) async throws -> PeerTubeVideoMatch?
}

public extension PeerTubeCatalogServiceProtocol {
    func discoverOpenVideos(category: MediaProjectType?, page: Int, limit: Int) async throws -> [MediaItem] { [] }
    func findPlayableMatch(title: String, originalTitle: String, expectedDurationMinutes: Int, isShort: Bool) async throws -> PeerTubeVideoMatch? { nil }
}

public final class PeerTubeCatalogService: PeerTubeCatalogServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let sepiaBaseURL = URL.constant("https://sepiasearch.org")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func discoverOpenVideos(category: MediaProjectType?, page: Int, limit: Int = 20) async throws -> [MediaItem] {
        let searchTerm: String = {
            switch category {
            case .shortFilm: return "short film"
            case .indieFestival: return "independent film"
            case .documentary: return "documentary"
            case .cartoonMovie, .cartoonSeries: return "animation"
            default: return "short film"
            }
        }()

        let start = max(page - 1, 0) * limit
        let ep = Endpoint(
            baseURL: sepiaBaseURL,
            path: "api/v1/search/videos",
            queryItems: [
                URLQueryItem(name: "search", value: searchTerm),
                URLQueryItem(name: "nsfw", value: "false"),
                URLQueryItem(name: "durationMin", value: "240"),
                URLQueryItem(name: "count", value: String(min(limit, 25))),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "sort", value: "-views")
            ],
            timeoutInterval: 5.5
        )
        let response = try await httpClient.send(ep, as: SepiaSearchResponseDTO.self)
        return response.data.compactMap { dto in
            mapToMediaItem(dto, fallbackType: category ?? .shortFilm)
        }
    }

    public func findPlayableMatch(
        title: String,
        originalTitle: String,
        expectedDurationMinutes: Int,
        isShort: Bool
    ) async throws -> PeerTubeVideoMatch? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let ep = Endpoint(
            baseURL: sepiaBaseURL,
            path: "api/v1/search/videos",
            queryItems: [
                URLQueryItem(name: "search", value: trimmed),
                URLQueryItem(name: "nsfw", value: "false"),
                URLQueryItem(name: "durationMin", value: isShort ? "180" : "900"),
                URLQueryItem(name: "count", value: "8")
            ],
            timeoutInterval: 5.0
        )
        let response = try await httpClient.send(ep, as: SepiaSearchResponseDTO.self)
        let normTitle = title.normalizedForComparison
        let normOrig = originalTitle.normalizedForComparison

        guard let match = response.data.first(where: { dto in
            let lower = dto.name.lowercased()
            if lower.contains("trailer") || lower.contains("teaser") || lower.contains("promo") || lower.contains("review") {
                return false
            }
            let normName = dto.name.normalizedForComparison
            return (!normTitle.isEmpty && (normName == normTitle || normName.contains(normTitle)))
                || (!normOrig.isEmpty && (normName == normOrig || normName.contains(normOrig)))
        }),
        let host = match.account?.host?.nilIfEmpty,
        !SourceURLValidator.isPrivateOrLocalHost(host.lowercased()),
        let instanceURL = URL(string: "https://\(host)") else {
            return nil
        }

        let detailsEp = Endpoint(
            baseURL: instanceURL,
            path: "api/v1/videos/\(match.uuid)",
            timeoutInterval: 5.0
        )
        let details = try await httpClient.send(detailsEp, as: PeerTubeVideoDetailDTO.self)
        if let playlist = details.streamingPlaylists?.first(where: { $0.playlistUrl.hasPrefix("https://") }),
           case .success(let hlsURL) = SourceURLValidator.validateSyntax(playlist.playlistUrl) {
            return PeerTubeVideoMatch(
                uuid: match.uuid,
                host: host,
                title: match.name,
                playbackURL: hlsURL,
                format: .hls,
                durationSeconds: TimeInterval(details.duration ?? match.duration ?? 0),
                qualities: [VideoQualityVariant(id: "pt-auto", tier: .auto, variantStreamURL: hlsURL, variantFormat: .hls)]
            )
        }

        let fileVariants: [VideoQualityVariant] = (details.files ?? []).compactMap { f in
            guard let urlStr = f.fileDownloadUrl ?? f.fileUrl,
                  urlStr.hasPrefix("https://"),
                  case .success(let fileURL) = SourceURLValidator.validateSyntax(urlStr),
                  ["mp4", "m4v", "mov"].contains(fileURL.pathExtension.lowercased()) else {
                return nil
            }
            let h = f.resolution?.id ?? 480
            let tier = VideoQualityTier.from(height: h)
            return VideoQualityVariant(id: "pt-\(h)", tier: tier, width: nil, height: h, variantStreamURL: fileURL, variantFormat: .mp4)
        }.sorted { $0.tier.resolutionPriorityRank > $1.tier.resolutionPriorityRank }

        guard let top = fileVariants.first, let primaryURL = top.variantStreamURL else {
            return nil
        }
        return PeerTubeVideoMatch(
            uuid: match.uuid,
            host: host,
            title: match.name,
            playbackURL: primaryURL,
            format: .mp4,
            durationSeconds: TimeInterval(details.duration ?? match.duration ?? 0),
            qualities: fileVariants
        )
    }

    private func mapToMediaItem(_ dto: SepiaVideoItemDTO, fallbackType: MediaProjectType) -> MediaItem? {
        let lower = dto.name.lowercased()
        if lower.contains("trailer") || lower.contains("teaser") || lower.contains("clip") {
            return nil
        }
        let durationSec = dto.duration ?? 0
        let durationMin = max(1, Int((Double(durationSec) / 60.0).rounded()))
        let type: MediaProjectType = (durationMin <= 42 && fallbackType != .documentary) ? .shortFilm : fallbackType
        let poster = (dto.thumbnailUrl ?? dto.previewUrl).flatMap(URL.init(string:))

        return MediaItem(
            id: "opencinema:movie:pt-\(dto.uuid)",
            externalIDs: [.openCinema: "pt-\(dto.uuid)"],
            primarySource: .openCinema,
            projectType: type,
            localizedTitle: dto.name,
            originalTitle: dto.name,
            synopsis: dto.description?.strippedHTML.nilIfEmpty ?? "Independent Creative Commons release on PeerTube.",
            releaseYear: Calendar.current.component(.year, from: Date()),
            countryOfOrigin: "FR",
            originalLanguage: dto.language?.id ?? "en",
            ageRating: "12+",
            genres: [type.displayName, "Creative Commons"],
            durationMinutes: durationMin,
            releaseStatus: .finished,
            ratings: MultiSourceRatings(),
            popularityScore: 340,
            posterURL: poster,
            backdropURL: poster,
            director: dto.account?.displayName ?? dto.account?.host ?? "Independent Creator"
        )
    }
}

private struct SepiaSearchResponseDTO: Decodable, Sendable {
    let data: [SepiaVideoItemDTO]
}

private struct SepiaVideoItemDTO: Decodable, Sendable {
    let uuid: String
    let name: String
    let description: String?
    let duration: Int?
    let thumbnailUrl: String?
    let previewUrl: String?
    let language: SepiaLanguageDTO?
    let account: SepiaAccountDTO?
}

private struct SepiaLanguageDTO: Decodable, Sendable {
    let id: String?
}

private struct SepiaAccountDTO: Decodable, Sendable {
    let host: String?
    let displayName: String?
}

private struct PeerTubeVideoDetailDTO: Decodable, Sendable {
    let duration: Int?
    let streamingPlaylists: [PeerTubePlaylistDTO]?
    let files: [PeerTubeFileDTO]?
}

private struct PeerTubePlaylistDTO: Decodable, Sendable {
    let playlistUrl: String
}

private struct PeerTubeFileDTO: Decodable, Sendable {
    let fileUrl: String?
    let fileDownloadUrl: String?
    let resolution: PeerTubeResolutionDTO?
}

private struct PeerTubeResolutionDTO: Decodable, Sendable {
    let id: Int?
}
