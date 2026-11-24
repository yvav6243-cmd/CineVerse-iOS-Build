import Foundation

public final class OpenStreamSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "open_stream"
    public let displayName = "CineVerse Instant Stream"

    private let iTunesService: ITunesCatalogServiceProtocol

    public init(iTunesService: ITunesCatalogServiceProtocol) {
        self.iTunesService = iTunesService
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        var collected: [VideoSourceDescriptor] = []
        var seenURLs: Set<String> = []

        // 1. Open Cinema full-length multi-mirror streams
        let openStreams = OpenCinemaLibrary.streams(forItemID: item.id)
        for (index, stream) in openStreams.enumerated() {
            guard seenURLs.insert(stream.url.absoluteString).inserted else { continue }
            let isHLS = stream.url.pathExtension.lowercased() == "m3u8"
                || stream.url.absoluteString.contains(".m3u8")
            collected.append(
                makeDirectDescriptor(
                    id: "openstream:\(item.id):\(index)",
                    url: stream.url,
                    format: isHLS ? .hls : .mp4,
                    label: "CineVerse Open Cinema · \(stream.label)",
                    description: stream.note,
                    language: item.originalLanguage,
                    episodeID: episode?.id
                )
            )
        }

        // 2. Direct verified HTTPS video stream attached on the item (e.g. Apple CDN .m4v)
        if let embeddedRaw = item.externalIDs[.openCinema],
           embeddedRaw.hasPrefix("https://"),
           let directURL = URL(string: embeddedRaw),
           directURL.scheme?.lowercased() == "https",
           seenURLs.insert(directURL.absoluteString).inserted {
            let fmt: VideoStreamFormat = (directURL.pathExtension.lowercased() == "m3u8" || embeddedRaw.contains(".m3u8")) ? .hls : .mp4
            collected.append(
                makeDirectDescriptor(
                    id: "openstream-direct:\(item.id)",
                    url: directURL,
                    format: fmt,
                    label: "Official Trailer (Apple)",
                    description: "Direct verified HTTPS stream",
                    language: item.originalLanguage,
                    episodeID: episode?.id
                )
            )
        }

        // 3. Multiple official Apple previews/trailers resolved automatically by title
        let isOpenCinemaItem = !openStreams.isEmpty
            || (item.reference?.provider == .openCinema && item.reference?.providerID.hasPrefix("open-") == true)

        if !isOpenCinemaItem {
            let matches = await iTunesService.findPlayablePreviews(
                title: item.localizedTitle,
                originalTitle: item.originalTitle,
                isEpisodic: item.projectType.isEpisodic,
                seasonNumber: episode?.seasonNumber,
                episodeNumber: episode?.episodeNumber,
                limit: 6
            )
            let epKey = episode?.id ?? "main"
            for (index, match) in matches.enumerated() {
                guard seenURLs.insert(match.url.absoluteString).inserted else { continue }
                collected.append(
                    makeDirectDescriptor(
                        id: "openstream-auto:\(item.id):\(epKey):\(index)",
                        url: match.url,
                        format: .mp4,
                        label: match.label,
                        description: "Official Apple preview stream ready in CineVerse player",
                        language: item.originalLanguage,
                        episodeID: episode?.id
                    )
                )
            }
        }

        return collected
    }

    private func makeDirectDescriptor(
        id: String,
        url: URL,
        format: VideoStreamFormat,
        label: String,
        description: String,
        language: String,
        episodeID: String?
    ) -> VideoSourceDescriptor {
        let lang = language.nilIfEmpty ?? "en"
        let audio = AudioTrackOption(
            id: "auto-audio-\(lang)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Original Direct Audio",
            isOriginal: true,
            isDefault: true
        )
        return VideoSourceDescriptor(
            id: id,
            providerID: self.id,
            providerName: label,
            sourceDescription: description,
            isAvailable: true,
            format: format,
            playbackURL: url,
            availableAudioTracks: [audio],
            episodeID: episodeID
        )
    }
}
