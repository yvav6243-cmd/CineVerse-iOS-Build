import Foundation
import AVFoundation

public actor MediaSourceInspector {
    private let httpClient: HTTPClient
    private let maxManifestBytes = 1_048_576 // 1 MB cap

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func inspect(
        _ descriptor: VideoSourceDescriptor,
        originalLanguage: String
    ) async -> VideoSourceDescriptor {
        guard descriptor.isAvailable, descriptor.format.isDirectlyPlayable else {
            return descriptor
        }

        var updated = descriptor
        switch descriptor.format {
        case .hls:
            guard let url = descriptor.playbackURL else { return descriptor }
            updated = await inspectHLS(descriptor, url: url, originalLanguage: originalLanguage)
        case .mp4, .localFile:
            guard let url = descriptor.playbackURL else { return descriptor }
            updated = await inspectAVAsset(descriptor, url: url, originalLanguage: originalLanguage)
        case .webm, .dash:
            guard let url = descriptor.playbackURL else { return descriptor }
            updated = inspectWebMedia(descriptor, url: url, originalLanguage: originalLanguage)
        case .externalOfficialService:
            return descriptor
        }

        updated.availableAudioTracks = AudioTrackNormalizer.normalize(updated.availableAudioTracks)
        return updated
    }

    private func inspectHLS(
        _ descriptor: VideoSourceDescriptor,
        url: URL,
        originalLanguage: String
    ) async -> VideoSourceDescriptor {
        var result = descriptor
        let endpoint = Endpoint(baseURL: url, path: "", method: .get, timeoutInterval: 15)
        guard let (data, _) = try? await httpClient.data(endpoint),
              data.count <= maxManifestBytes,
              let text = String(data: data, encoding: .utf8) else {
            if result.availableQualities.isEmpty {
                result.availableQualities = [VideoQualityVariant(id: "hls-auto", tier: .auto)]
            }
            if result.availableAudioTracks.isEmpty {
                result.availableAudioTracks = [defaultAudioTrack(languageCode: originalLanguage, studio: "HLS Default")]
            }
            return result
        }

        let parsed = HLSManifestParser.parse(
            manifestText: text,
            baseURL: url,
            originalLanguage: originalLanguage
        )

        var bestByTier: [VideoQualityTier: VideoQualityVariant] = [:]
        for variant in parsed.qualities where variant.tier != .auto {
            if let existing = bestByTier[variant.tier] {
                if (variant.bandwidthBitsPerSecond ?? 0) > (existing.bandwidthBitsPerSecond ?? 0) {
                    bestByTier[variant.tier] = variant
                }
            } else {
                bestByTier[variant.tier] = variant
            }
        }

        var cleanedQualities = bestByTier.values.sorted { lhs, rhs in
            (lhs.height ?? 0) > (rhs.height ?? 0)
        }
        cleanedQualities.insert(VideoQualityVariant(id: "hls-auto", tier: .auto), at: 0)
        result.availableQualities = cleanedQualities

        var seenAudioKeys: Set<String> = []
        var dedupedAudio: [AudioTrackOption] = []
        for track in parsed.audioTracks {
            let uriPart = track.dedicatedAudioStreamURL?.absoluteString ?? track.hlsGroupID ?? ""
            let key = "\(track.languageCode.lowercased())|\(track.voiceoverStudio.lowercased())|\(uriPart)"
            if seenAudioKeys.insert(key).inserted {
                dedupedAudio.append(track)
            }
        }

        if !dedupedAudio.isEmpty {
            result.availableAudioTracks = dedupedAudio
        } else if result.availableAudioTracks.isEmpty {
            result.availableAudioTracks = [defaultAudioTrack(languageCode: originalLanguage, studio: "HLS Stream Audio")]
        }

        let mergedSubs = mergeSubtitles(existing: result.availableSubtitles, discovered: parsed.subtitles)
        result.availableSubtitles = mergedSubs
        return result
    }

    private func inspectAVAsset(
        _ descriptor: VideoSourceDescriptor,
        url: URL,
        originalLanguage: String
    ) async -> VideoSourceDescriptor {
        var result = descriptor
        let asset = AVURLAsset(url: url)

        if result.availableQualities.isEmpty {
            var variants: [VideoQualityVariant] = []
            if let videoTracks = try? await asset.loadTracks(withMediaType: .video),
               let firstTrack = videoTracks.first {
                if let naturalSize = try? await firstTrack.load(.naturalSize),
                   let transform = try? await firstTrack.load(.preferredTransform) {
                    let transformed = naturalSize.applying(transform)
                    let width = Int(abs(transformed.width).rounded())
                    let height = Int(abs(transformed.height).rounded())
                    if height > 0 {
                        let tier = VideoQualityTier.from(height: height)
                        variants.append(
                            VideoQualityVariant(
                                id: "av-\(tier.rawValue)",
                                tier: tier,
                                width: width,
                                height: height,
                                variantStreamURL: url
                            )
                        )
                    }
                }
            }
            result.availableQualities = variants.isEmpty
                ? [VideoQualityVariant(id: "av-auto", tier: .auto, variantStreamURL: url)]
                : variants
        }

        var audioOptions: [AudioTrackOption] = []
        if let audibleGroup = try? await asset.loadMediaSelectionGroup(for: .audible) {
            for (index, option) in audibleGroup.options.enumerated() {
                let langCode = option.locale?.language.languageCode?.identifier
                    ?? option.extendedLanguageTag
                    ?? originalLanguage
                let name = option.displayName
                let isOrig = langCode.lowercased() == originalLanguage.lowercased()
                audioOptions.append(
                    AudioTrackOption(
                        id: "av-audio-\(index)-\(langCode)",
                        languageCode: langCode,
                        displayName: LanguageCatalog.displayName(forLanguageCode: langCode),
                        voiceoverStudio: name.isEmpty ? "Embedded Track \(index + 1)" : name,
                        isOriginal: isOrig,
                        isDefault: index == 0
                    )
                )
            }
        }
        if audioOptions.isEmpty && result.availableAudioTracks.isEmpty {
            audioOptions = [defaultAudioTrack(languageCode: originalLanguage, studio: "Embedded Audio")]
        }
        if !audioOptions.isEmpty {
            result.availableAudioTracks = audioOptions
        }

        var embeddedSubs: [SubtitleTrackOption] = []
        if let legibleGroup = try? await asset.loadMediaSelectionGroup(for: .legible) {
            for (index, option) in legibleGroup.options.enumerated() {
                let langCode = option.locale?.language.languageCode?.identifier
                    ?? option.extendedLanguageTag
                    ?? "en"
                embeddedSubs.append(
                    SubtitleTrackOption(
                        id: "av-sub-\(index)-\(langCode)",
                        languageCode: langCode,
                        displayName: option.displayName.isEmpty
                            ? LanguageCatalog.displayName(forLanguageCode: langCode)
                            : option.displayName,
                        format: .embeddedHLS
                    )
                )
            }
        }
        result.availableSubtitles = mergeSubtitles(existing: result.availableSubtitles, discovered: embeddedSubs)
        return result
    }

    private func defaultAudioTrack(languageCode: String, studio: String) -> AudioTrackOption {
        let lang = languageCode.nilIfEmpty ?? "und"
        return AudioTrackOption(
            id: "default-audio-\(lang)",
            languageCode: lang,
            displayName: lang == "und" ? "Default Audio" : LanguageCatalog.displayName(forLanguageCode: lang),
            voiceoverStudio: studio,
            isOriginal: true,
            isDefault: true
        )
    }

    private func inspectWebMedia(
        _ descriptor: VideoSourceDescriptor,
        url: URL,
        originalLanguage: String
    ) -> VideoSourceDescriptor {
        var result = descriptor
        if result.availableQualities.isEmpty {
            result.availableQualities = [
                VideoQualityVariant(
                    id: "web-auto",
                    tier: .auto,
                    variantStreamURL: url,
                    variantFormat: descriptor.format
                )
            ]
        }
        if result.availableAudioTracks.isEmpty {
            result.availableAudioTracks = [defaultAudioTrack(languageCode: originalLanguage, studio: "Original Audio")]
        }
        return result
    }

    private func mergeSubtitles(
        existing: [SubtitleTrackOption],
        discovered: [SubtitleTrackOption]
    ) -> [SubtitleTrackOption] {
        var seen: Set<String> = []
        var combined: [SubtitleTrackOption] = []
        for sub in existing + discovered {
            if seen.insert(sub.id).inserted {
                combined.append(sub)
            }
        }
        return combined
    }
}

public enum AudioTrackNormalizer {
    public static func normalize(_ tracks: [AudioTrackOption]) -> [AudioTrackOption] {
        guard tracks.count > 1 else { return tracks }

        // Count how many non-original tracks share the same language AND generic/identical studio label
        var countsByLangAndName: [String: Int] = [:]
        for track in tracks where !track.isOriginal {
            let key = "\(track.languageCode.lowercased())|\(genericKey(for: track))"
            countsByLangAndName[key, default: 0] += 1
        }

        var runningIndexByKey: [String: Int] = [:]
        return tracks.map { track in
            guard !track.isOriginal else { return track }
            let key = "\(track.languageCode.lowercased())|\(genericKey(for: track))"
            guard (countsByLangAndName[key] ?? 0) > 1 else {
                // Single dub in this language: if studio merely repeats language name, clarify as "<Language> Dub"
                if track.voiceoverStudio.lowercased() == track.displayName.lowercased() {
                    return AudioTrackOption(
                        id: track.id,
                        languageCode: track.languageCode,
                        displayName: track.displayName,
                        voiceoverStudio: "\(track.displayName) Dub",
                        voiceoverKind: .dub,
                        isOriginal: false,
                        isDefault: track.isDefault,
                        hlsGroupID: track.hlsGroupID,
                        dedicatedAudioStreamURL: track.dedicatedAudioStreamURL,
                        alternateMuxedVideoURL: track.alternateMuxedVideoURL,
                        channelCount: track.channelCount
                    )
                }
                return track
            }

            let nextNum = (runningIndexByKey[key] ?? 0) + 1
            runningIndexByKey[key] = nextNum
            return AudioTrackOption(
                id: track.id,
                languageCode: track.languageCode,
                displayName: track.displayName,
                voiceoverStudio: "\(track.displayName) Dub \(nextNum)",
                voiceoverKind: .dub,
                isOriginal: false,
                isDefault: track.isDefault,
                hlsGroupID: track.hlsGroupID,
                dedicatedAudioStreamURL: track.dedicatedAudioStreamURL,
                alternateMuxedVideoURL: track.alternateMuxedVideoURL,
                channelCount: track.channelCount
            )
        }
    }

    private static func genericKey(for track: AudioTrackOption) -> String {
        let lower = track.voiceoverStudio.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty || lower == track.displayName.lowercased() || lower.hasPrefix("embedded track") || lower == "audio" || lower == "dub" {
            return "generic"
        }
        return lower
    }
}
