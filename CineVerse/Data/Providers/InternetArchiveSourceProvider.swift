import Foundation

public final class InternetArchiveSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "internet_archive"
    public let displayName = "Internet Archive (Public Domain / CC)"

    private let service: InternetArchiveServiceProtocol

    public init(service: InternetArchiveServiceProtocol) {
        self.service = service
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        let supportedTypes: Set<MediaProjectType> = [.movie, .cartoonMovie, .documentary, .special]
        guard supportedTypes.contains(item.projectType), episode == nil else {
            return []
        }

        guard let match = try? await service.findPlayableMatch(
            title: item.localizedTitle,
            originalTitle: item.originalTitle,
            year: item.releaseYear,
            originalLanguage: item.originalLanguage
        ) else {
            return []
        }

        let audio = AudioTrackOption(
            id: "ia-audio-\(match.identifier)",
            languageCode: match.originalLanguage,
            displayName: LanguageCatalog.displayName(forLanguageCode: match.originalLanguage),
            voiceoverStudio: "Archive Original Audio",
            isOriginal: true,
            isDefault: true
        )

        return [
            VideoSourceDescriptor(
                id: "ia:\(match.identifier)",
                providerID: id,
                providerName: displayName,
                sourceDescription: "Verified archive.org public domain / CC release",
                isAvailable: true,
                format: .mp4,
                playbackURL: match.primaryPlaybackURL,
                availableQualities: match.qualities,
                availableAudioTracks: [audio],
                availableSubtitles: match.subtitles
            )
        ]
    }
}
