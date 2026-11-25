import Foundation

public final class PeerTubeSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "peertube_cc"
    public let displayName = "PeerTube Creative Commons"

    private let service: PeerTubeCatalogServiceProtocol

    public init(service: PeerTubeCatalogServiceProtocol) {
        self.service = service
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        guard episode == nil else { return [] }
        let eligible: Set<MediaProjectType> = [.shortFilm, .indieFestival, .documentary, .cartoonMovie, .special]
        guard eligible.contains(item.projectType) || item.id.contains(":pt-") else {
            return []
        }

        let isShort = item.projectType == .shortFilm || (item.durationMinutes > 0 && item.durationMinutes <= 42)
        guard let match = try? await service.findPlayableMatch(
            title: item.localizedTitle,
            originalTitle: item.originalTitle,
            expectedDurationMinutes: item.durationMinutes,
            isShort: isShort
        ) else {
            return []
        }

        let lang = item.originalLanguage.nilIfEmpty ?? "en"
        let audio = AudioTrackOption(
            id: "pt-audio-\(lang)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Original Creator Audio",
            voiceoverKind: .original,
            isOriginal: true,
            isDefault: true
        )

        return [
            VideoSourceDescriptor(
                id: "peertube:\(match.uuid)",
                providerID: id,
                providerName: "PeerTube Creative Commons (\(match.host))",
                sourceDescription: "Verified independent/CC full-length video",
                isAvailable: true,
                format: match.format,
                playbackURL: match.playbackURL,
                availableQualities: match.qualities,
                availableAudioTracks: [audio],
                durationSeconds: match.durationSeconds > 0 ? match.durationSeconds : nil,
                healthStatus: .unchecked
            )
        ]
    }
}
