import Foundation

public final class DirectLinkSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "direct_link"
    public let displayName = "Direct Stream URL"

    private let fetchSources: @MainActor (String, Int?, Int?) -> [UserVideoSourceDTO]
    private let videoStore: LocalVideoStore

    public init(
        videoStore: LocalVideoStore = .shared,
        fetchSources: @escaping @MainActor (String, Int?, Int?) -> [UserVideoSourceDTO]
    ) {
        self.videoStore = videoStore
        self.fetchSources = fetchSources
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        var descriptors: [VideoSourceDescriptor] = []

        if let episodeURL = episode?.directStreamURL, episodeURL.scheme?.lowercased() == "https" {
            let fmt: VideoStreamFormat = episodeURL.pathExtension.lowercased() == "m3u8" ? .hls : .mp4
            descriptors.append(
                VideoSourceDescriptor(
                    id: "direct-ep:\(episode?.id ?? item.id)",
                    providerID: id,
                    providerName: "Episode Direct Stream",
                    sourceDescription: episodeURL.host ?? "HTTPS Stream",
                    isAvailable: true,
                    format: fmt,
                    playbackURL: episodeURL,
                    episodeID: episode?.id
                )
            )
        }

        let records = await fetchSources(item.id, episode?.seasonNumber, episode?.episodeNumber)
        let directRecords = records.filter { $0.kindRaw == UserVideoSourceKind.directLink.rawValue }

        for dto in directRecords {
            guard let raw = dto.urlString,
                  case .success(let url) = SourceURLValidator.validateSyntax(raw) else {
                continue
            }
            let fmt: VideoStreamFormat = url.pathExtension.lowercased() == "m3u8" ? .hls : .mp4
            let subtitles = dto.subtitles.map { sub in
                let subURL: URL? = sub.relativePathOrURL.hasPrefix("https://")
                    ? URL(string: sub.relativePathOrURL)
                    : videoStore.resolveURL(forRelativePath: sub.relativePathOrURL)
                return SubtitleTrackOption(
                    id: sub.id,
                    languageCode: sub.languageCode,
                    displayName: sub.displayName,
                    format: SubtitleFormat(rawValue: sub.formatRaw) ?? .srt,
                    externalURL: subURL
                )
            }

            descriptors.append(
                VideoSourceDescriptor(
                    id: "direct:\(dto.id.uuidString)",
                    providerID: id,
                    providerName: dto.label.nilIfEmpty ?? (url.host ?? "Direct Stream"),
                    sourceDescription: url.host ?? "Custom HTTPS Stream",
                    isAvailable: true,
                    format: fmt,
                    playbackURL: url,
                    availableSubtitles: subtitles,
                    episodeID: episode?.id
                )
            )
        }

        return descriptors
    }
}
