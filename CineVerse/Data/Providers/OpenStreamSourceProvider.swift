import Foundation

public final class OpenStreamSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "open_stream"
    public let displayName = "CineVerse Instant Stream"

    private let iTunesService: ITunesCatalogServiceProtocol

    public init(iTunesService: ITunesCatalogServiceProtocol) {
        self.iTunesService = iTunesService
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        // 1. Check if item is a full-length CineVerse Open Cinema title (HLS / MP4)
        if let ref = item.reference, ref.provider == .openCinema, ref.providerID.hasPrefix("open-"),
           let openStream = iTunesService.streamURLForOpenCinema(providerID: ref.providerID) {
            return [
                VideoSourceDescriptor(
                    id: "openstream:\(item.id)",
                    providerID: id,
                    providerName: openStream.label,
                    sourceDescription: "Full-length adaptive HD cinema stream",
                    isAvailable: true,
                    format: openStream.format,
                    playbackURL: openStream.url,
                    episodeID: episode?.id
                )
            ]
        }

        // 2. Check if item already carries a direct verified HTTPS video stream URL (e.g. Apple CDN .m4v)
        if let embeddedRaw = item.externalIDs[.openCinema],
           embeddedRaw.hasPrefix("https://"),
           let directURL = URL(string: embeddedRaw) {
            let fmt: VideoStreamFormat = embeddedRaw.contains(".m3u8") ? .hls : .mp4
            return [
                makeDirectDescriptor(
                    id: "openstream-direct:\(item.id)",
                    url: directURL,
                    format: fmt,
                    label: "CineVerse Direct Stream (HD)",
                    language: item.originalLanguage,
                    episodeID: episode?.id
                )
            ]
        }

        // 3. Automatically resolve a direct playable HTTPS stream by title via Apple Cinema Lookup (no user URL input needed!)
        if let resolvedURL = await iTunesService.findPlayablePreviewURL(
            title: item.localizedTitle,
            originalTitle: item.originalTitle,
            isEpisodic: item.projectType.isEpisodic,
            episodeNumber: episode?.episodeNumber
        ) {
            return [
                makeDirectDescriptor(
                    id: "openstream-auto:\(item.id):\(episode?.id ?? "main")",
                    url: resolvedURL,
                    format: .mp4,
                    label: "CineVerse Direct Stream (Official HD Preview)",
                    language: item.originalLanguage,
                    episodeID: episode?.id
                )
            ]
        }

        return []
    }

    private func makeDirectDescriptor(
        id: String,
        url: URL,
        format: VideoStreamFormat,
        label: String,
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
            sourceDescription: "Ready to play without external links",
            isAvailable: true,
            format: format,
            playbackURL: url,
            availableAudioTracks: [audio],
            episodeID: episodeID
        )
    }
}
