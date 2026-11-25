import Foundation

/// Resolves ONLY verified full-length streams from CineVerse Open Cinema & episode direct streams.
/// Short 2-minute trailers/previews are strictly excluded from movie/episode video sources
/// and remain exclusively on the dedicated Watch Trailer action.
public final class OpenStreamSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "open_stream"
    public let displayName = "CineVerse Open Cinema"

    private let iTunesService: ITunesCatalogServiceProtocol

    public init(iTunesService: ITunesCatalogServiceProtocol) {
        self.iTunesService = iTunesService
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        var collected: [VideoSourceDescriptor] = []
        var seenURLs: Set<String> = []

        // 1. Direct HTTPS episode stream if explicitly attached on the episode model
        if let epURL = episode?.directStreamURL,
           epURL.scheme?.lowercased() == "https",
           seenURLs.insert(epURL.absoluteString).inserted {
            let fmt = Self.detectFormat(for: epURL)
            collected.append(
                makeFullLengthDescriptor(
                    id: "openstream-ep:\(episode?.id ?? item.id)",
                    url: epURL,
                    format: fmt,
                    label: "CineVerse Open Episode Stream",
                    description: "Full episode stream",
                    language: item.originalLanguage,
                    durationMinutes: episode?.durationMinutes ?? item.durationMinutes,
                    episodeID: episode?.id
                )
            )
        }

        // 2. Open Cinema full-length multi-mirror streams (only for non-episodic or fallback)
        if episode == nil || episode?.directStreamURL == nil {
            let openStreams = OpenCinemaLibrary.streams(forItemID: item.id)
            for (index, stream) in openStreams.enumerated() {
                guard seenURLs.insert(stream.url.absoluteString).inserted else { continue }
                let fmt = Self.detectFormat(for: stream.url)
                collected.append(
                    makeFullLengthDescriptor(
                        id: "openstream:\(item.id):\(index)",
                        url: stream.url,
                        format: fmt,
                        label: "CineVerse Open Cinema · \(stream.label)",
                        description: stream.note,
                        language: item.originalLanguage,
                        durationMinutes: item.durationMinutes,
                        episodeID: episode?.id
                    )
                )
            }
        }

        return collected
    }

    private static func detectFormat(for url: URL) -> VideoStreamFormat {
        let ext = url.pathExtension.lowercased()
        let raw = url.absoluteString.lowercased()
        if ext == "m3u8" || raw.contains(".m3u8") { return .hls }
        if ext == "webm" { return .webm }
        if ext == "mpd" { return .dash }
        return .mp4
    }

    private func makeFullLengthDescriptor(
        id: String,
        url: URL,
        format: VideoStreamFormat,
        label: String,
        description: String,
        language: String,
        durationMinutes: Int,
        episodeID: String?
    ) -> VideoSourceDescriptor {
        let lang = language.nilIfEmpty ?? "en"
        let audio = AudioTrackOption(
            id: "auto-audio-\(lang)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Original Audio",
            voiceoverKind: .original,
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
            episodeID: episodeID,
            durationSeconds: durationMinutes > 0 ? TimeInterval(durationMinutes * 60) : nil,
            healthStatus: .unchecked
        )
    }
}
