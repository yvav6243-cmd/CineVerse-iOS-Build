import Foundation

public final class WikimediaSourceProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "wikimedia_cinema"
    public let displayName = "Wikimedia Public Domain Cinema"

    private let service: WikimediaCinemaServiceProtocol

    public init(service: WikimediaCinemaServiceProtocol) {
        self.service = service
    }

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        // 1. Check if episode or item carries a direct Wikimedia file reference (`wmfile:File:...`)
        if let epStream = episode?.directStreamURL, epStream.scheme == "wmfile" {
            let fileTitle = epStream.AbsoluteWikimediaTitle
            if let match = try? await service.resolveByFileTitle(fileTitle, originalLanguage: item.originalLanguage) {
                return buildDescriptors(from: match, itemID: item.id, episodeID: episode?.id)
            }
        }

        if let rawExt = item.externalIDs[.openCinema], rawExt.hasPrefix("wmfile:") {
            let fileTitle = String(rawExt.dropFirst("wmfile:".count))
            if let match = try? await service.resolveByFileTitle(fileTitle, originalLanguage: item.originalLanguage) {
                return buildDescriptors(from: match, itemID: item.id, episodeID: episode?.id)
            }
        }

        // Skip generic search for Open Cinema items that already have dedicated HLS streams
        if !OpenCinemaLibrary.streams(forItemID: item.id).isEmpty {
            return []
        }

        // 2. Search Wikimedia Commons for full-length public domain feature films or episodes
        guard let match = try? await service.findFullLengthMatch(
            title: item.localizedTitle,
            originalTitle: item.originalTitle,
            year: item.releaseYear,
            expectedDurationMinutes: episode?.durationMinutes ?? item.durationMinutes,
            isEpisodic: item.projectType.isEpisodic,
            episodeTitle: episode?.title,
            originalLanguage: item.originalLanguage
        ) else {
            return []
        }

        return buildDescriptors(from: match, itemID: item.id, episodeID: episode?.id)
    }

    private func buildDescriptors(
        from match: WikimediaVideoMatch,
        itemID: String,
        episodeID: String?
    ) -> [VideoSourceDescriptor] {
        let lang = match.originalLanguage.nilIfEmpty ?? "en"
        let audio = AudioTrackOption(
            id: "wm-audio-\(lang)",
            languageCode: lang,
            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: "Original Audio",
            voiceoverKind: .original,
            isOriginal: true,
            isDefault: true
        )

        var descriptors: [VideoSourceDescriptor] = []

        // High-res 4K / 2K / 1080p WebM / MP4 primary source
        let highResQualities = match.qualities.filter { $0.variantFormat != .dash }
        if let best = highResQualities.first, let bestURL = best.variantStreamURL {
            descriptors.append(
                VideoSourceDescriptor(
                    id: "wm-hd:\(itemID):\(episodeID ?? "main")",
                    providerID: id,
                    providerName: "Wikimedia Cinema (\(best.tier.rawValue) Full Video)",
                    sourceDescription: "Verified full-length public domain film · \(Int(match.durationSeconds / 60)) min",
                    isAvailable: true,
                    format: best.variantFormat ?? match.primaryFormat,
                    playbackURL: bestURL,
                    availableQualities: highResQualities,
                    availableAudioTracks: [audio],
                    availableSubtitles: match.subtitles,
                    episodeID: episodeID,
                    durationSeconds: match.durationSeconds,
                    healthStatus: .online(latencyMs: 0)
                )
            )
        }

        // Also surface dedicated native AVPlayer QuickTime (.mov) stream if primary is WebM so PiP/AirPlay is always available too
        if match.primaryFormat == .webm,
           let nativeMov = match.qualities.first(where: { $0.variantFormat == .mp4 }),
           let movURL = nativeMov.variantStreamURL {
            descriptors.append(
                VideoSourceDescriptor(
                    id: "wm-native:\(itemID):\(episodeID ?? "main")",
                    providerID: id,
                    providerName: "Wikimedia Native AVPlayer (\(nativeMov.tier.rawValue) PiP/AirPlay)",
                    sourceDescription: "Hardware AVFoundation QuickTime stream · \(Int(match.durationSeconds / 60)) min",
                    isAvailable: true,
                    format: .mp4,
                    playbackURL: movURL,
                    availableQualities: [nativeMov],
                    availableAudioTracks: [audio],
                    availableSubtitles: match.subtitles,
                    episodeID: episodeID,
                    durationSeconds: match.durationSeconds,
                    healthStatus: .online(latencyMs: 0)
                )
            )
        }

        return descriptors
    }
}

private extension URL {
    var AbsoluteWikimediaTitle: String {
        let raw = absoluteString.replacingOccurrences(of: "wmfile://", with: "")
            .replacingOccurrences(of: "wmfile:", with: "")
        return raw.removingPercentEncoding ?? raw
    }
}
