import Foundation

public final class InternetArchiveSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "internet_archive"
    public let displayName = "Internet Archive (Public Domain / CC)"

    private let service: InternetArchiveServiceProtocol

    public init(service: InternetArchiveServiceProtocol) {
        self.service = service
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        guard episode == nil || item.primarySource == .internetArchive else {
            return []
        }

        if let iaID = item.externalIDs[.internetArchive]?.nilIfEmpty,
           let match = try? await service.findPlayableByIdentifier(iaID, originalLanguage: item.originalLanguage) {
            return [buildDescriptor(from: match, item: item, episode: episode)]
        }

        let supportedTypes: Set<MediaProjectType> = [
            .movie, .cartoonMovie, .documentary, .special,
            .shortFilm, .indieFestival, .tvSeries, .cartoonSeries, .other
        ]
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

        return [buildDescriptor(from: match, item: item, episode: episode)]
    }

    private func buildDescriptor(
        from match: InternetArchiveVideoMatch,
        item: MediaItem,
        episode: MediaEpisode?
    ) -> VideoSourceDescriptor {
        let lang = match.originalLanguage.nilIfEmpty ?? item.originalLanguage.nilIfEmpty ?? "en"
        let audio = AudioTrackOption(
            id: "ia-audio-\(match.identifier)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Archive Original Audio",
            voiceoverKind: .original,
            isOriginal: true,
            isDefault: true
        )

        return VideoSourceDescriptor(
            id: "ia:\(match.identifier)",
            providerID: id,
            providerName: displayName,
            sourceDescription: "Verified archive.org public domain / CC release",
            isAvailable: true,
            format: .mp4,
            playbackURL: match.primaryPlaybackURL,
            availableQualities: match.qualities,
            availableAudioTracks: [audio],
            availableSubtitles: match.subtitles,
            episodeID: episode?.id,
            durationSeconds: match.durationSeconds
        )
    }
}
