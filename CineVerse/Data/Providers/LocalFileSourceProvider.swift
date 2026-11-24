import Foundation
import SwiftData

public final class LocalFileSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "local_file"
    public let displayName = "On-Device Video"

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
        let records = await fetchSources(item.id, episode?.seasonNumber, episode?.episodeNumber)
        let localRecords = records.filter { $0.kindRaw == UserVideoSourceKind.localFile.rawValue }

        return localRecords.compactMap { dto -> VideoSourceDescriptor? in
            guard let relPath = dto.urlString else { return nil }
            let fileURL = videoStore.resolveURL(forRelativePath: relPath)
            let exists = videoStore.fileExists(relativePath: relPath)
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

            return VideoSourceDescriptor(
                id: "local:\(dto.id.uuidString)",
                providerID: id,
                providerName: dto.label.nilIfEmpty ?? displayName,
                sourceDescription: exists ? "Stored locally on iPhone" : "Local file is no longer on disk",
                isAvailable: exists,
                format: .localFile,
                playbackURL: exists ? fileURL : nil,
                availableSubtitles: subtitles,
                episodeID: episode?.id
            )
        }
    }
}
