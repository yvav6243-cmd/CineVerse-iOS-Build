import Foundation

public struct ParsedHLSManifest: Sendable, Equatable {
    public let qualities: [VideoQualityVariant]
    public let audioTracks: [AudioTrackOption]
    public let subtitles: [SubtitleTrackOption]
}

public enum HLSManifestParser {
    public static func parse(
        manifestText: String,
        baseURL: URL,
        originalLanguage: String
    ) -> ParsedHLSManifest {
        let lines = manifestText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var rawVariants: [VideoQualityVariant] = []
        var audioTracks: [AudioTrackOption] = []
        var subtitles: [SubtitleTrackOption] = []
        var pendingStreamInfAttributes: [String: String]?

        for line in lines {
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXT-X-MEDIA:") {
                let rawAttrs = String(line.dropFirst("#EXT-X-MEDIA:".count))
                let attrs = parseAttributes(rawAttrs)
                let mediaType = attrs["TYPE"]?.uppercased() ?? ""
                let groupID = attrs["GROUP-ID"] ?? "default"
                let lang = (attrs["LANGUAGE"] ?? "und").lowercased()
                let name = attrs["NAME"] ?? LanguageCatalog.displayName(forLanguageCode: lang)
                let isDefault = (attrs["DEFAULT"]?.uppercased() == "YES")
                let resolvedURI = attrs["URI"].flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

                if mediaType == "AUDIO" {
                    let channels = Int(attrs["CHANNELS"]?.split(separator: "/").first ?? "2") ?? 2
                    let isOriginal = lang == originalLanguage.lowercased()
                        || name.lowercased().contains("original")
                    audioTracks.append(
                        AudioTrackOption(
                            id: "hls-audio-\(groupID)-\(lang)-\(audioTracks.count)",
                            languageCode: lang,
                            displayName: LanguageCatalog.displayName(forLanguageCode: lang),
                            voiceoverStudio: name,
                            isOriginal: isOriginal,
                            isDefault: isDefault,
                            hlsGroupID: groupID,
                            dedicatedAudioStreamURL: resolvedURI,
                            channelCount: channels
                        )
                    )
                } else if mediaType == "SUBTITLES" {
                    subtitles.append(
                        SubtitleTrackOption(
                            id: "hls-sub-\(groupID)-\(lang)-\(subtitles.count)",
                            languageCode: lang,
                            displayName: name,
                            format: .embeddedHLS,
                            externalURL: resolvedURI,
                            isDefault: isDefault
                        )
                    )
                }
            } else if line.hasPrefix("#EXT-X-STREAM-INF:") {
                let rawAttrs = String(line.dropFirst("#EXT-X-STREAM-INF:".count))
                pendingStreamInfAttributes = parseAttributes(rawAttrs)
            } else if !line.hasPrefix("#"), let attrs = pendingStreamInfAttributes {
                pendingStreamInfAttributes = nil
                let variantURL = URL(string: line, relativeTo: baseURL)?.absoluteURL
                let bandwidth = attrs["BANDWIDTH"].flatMap(Int.init)
                let resolution = parseResolution(attrs["RESOLUTION"])
                let tier = resolution.map { VideoQualityTier.from(height: $0.height) } ?? .auto

                rawVariants.append(
                    VideoQualityVariant(
                        id: "hls-q-\(tier.rawValue)-\(bandwidth ?? 0)",
                        tier: tier,
                        bandwidthBitsPerSecond: bandwidth,
                        width: resolution?.width,
                        height: resolution?.height,
                        variantStreamURL: variantURL
                    )
                )
            }
        }

        // Deduplicate by quality tier keeping the highest-bandwidth stream
        var bestByTier: [VideoQualityTier: VideoQualityVariant] = [:]
        for variant in rawVariants {
            if let existing = bestByTier[variant.tier] {
                if (variant.bandwidthBitsPerSecond ?? 0) > (existing.bandwidthBitsPerSecond ?? 0) {
                    bestByTier[variant.tier] = variant
                }
            } else {
                bestByTier[variant.tier] = variant
            }
        }

        var sortedQualities = bestByTier.values
            .filter { $0.tier != .auto }
            .sorted { ($0.height ?? 0) > ($1.height ?? 0) }

        if sortedQualities.count > 1 || sortedQualities.isEmpty {
            sortedQualities.insert(
                VideoQualityVariant(id: "hls-q-auto", tier: .auto),
                at: 0
            )
        }

        return ParsedHLSManifest(
            qualities: sortedQualities,
            audioTracks: audioTracks,
            subtitles: subtitles
        )
    }

    public static func parseAttributes(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var value = ""
        var readingKey = true
        var inQuotes = false

        for ch in raw {
            if readingKey {
                if ch == "=" {
                    readingKey = false
                } else {
                    key.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes.toggle()
                } else if ch == "," && !inQuotes {
                    let cleanKey = key.trimmingCharacters(in: .whitespaces).uppercased()
                    if !cleanKey.isEmpty {
                        result[cleanKey] = value.trimmingCharacters(in: .whitespaces)
                    }
                    key = ""
                    value = ""
                    readingKey = true
                } else {
                    value.append(ch)
                }
            }
        }

        let cleanKey = key.trimmingCharacters(in: .whitespaces).uppercased()
        if !cleanKey.isEmpty {
            result[cleanKey] = value.trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    private static func parseResolution(_ raw: String?) -> (width: Int, height: Int)? {
        guard let raw else { return nil }
        let parts = raw.lowercased().split(separator: "x")
        guard parts.count == 2,
              let w = Int(parts[0]),
              let h = Int(parts[1]),
              w > 0, h > 0 else {
            return nil
        }
        return (w, h)
    }
}
