import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics

public enum VideoPicturePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard = "Standard"
    case vividCinema = "Vivid Cinema"
    case warmTheatre = "Warm Theatre"
    case crispContrast = "Crisp HD"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .standard: return "tv"
        case .vividCinema: return "sparkles.tv"
        case .warmTheatre: return "sun.max.fill"
        case .crispContrast: return "wand.and.stars"
        }
    }

    public var subtitle: String {
        switch self {
        case .standard: return "Original neutral studio color balance"
        case .vividCinema: return "Enhanced OLED color depth and punch"
        case .warmTheatre: return "Soft theatrical highlight warmth"
        case .crispContrast: return "Sharper micro-contrast for SD/HD streams"
        }
    }

    public var contrast: Double {
        switch self {
        case .standard: return 1.0
        case .vividCinema: return 1.07
        case .warmTheatre: return 1.05
        case .crispContrast: return 1.12
        }
    }

    public var saturation: Double {
        switch self {
        case .standard: return 1.0
        case .vividCinema: return 1.15
        case .warmTheatre: return 1.08
        case .crispContrast: return 1.04
        }
    }

    public var brightness: Double {
        switch self {
        case .standard: return 0.0
        case .vividCinema: return 0.01
        case .warmTheatre: return 0.015
        case .crispContrast: return 0.0
        }
    }
}

public struct PlaybackQualityDiagnostics: Equatable, Sendable {
    public let videoWidth: Int
    public let videoHeight: Int
    public let observedBitrateBitsPerSecond: Double
    public let framesPerSecond: Double
    public let dynamicRange: String
    public let videoCodec: String?

    public static let empty = PlaybackQualityDiagnostics(
        videoWidth: 0,
        videoHeight: 0,
        observedBitrateBitsPerSecond: 0,
        framesPerSecond: 0,
        dynamicRange: "SDR",
        videoCodec: nil
    )

    public init(
        videoWidth: Int,
        videoHeight: Int,
        observedBitrateBitsPerSecond: Double,
        framesPerSecond: Double = 0,
        dynamicRange: String = "SDR",
        videoCodec: String? = nil
    ) {
        self.videoWidth = max(0, videoWidth)
        self.videoHeight = max(0, videoHeight)
        self.observedBitrateBitsPerSecond = observedBitrateBitsPerSecond.isFinite
            ? max(0, observedBitrateBitsPerSecond)
            : 0
        self.framesPerSecond = framesPerSecond.isFinite ? max(0, framesPerSecond) : 0
        self.dynamicRange = dynamicRange.isEmpty ? "SDR" : dynamicRange
        self.videoCodec = videoCodec?.nilIfEmpty
    }

    /// Honest resolution badge computed strictly from actual decoded video frame height (never upscaled or faked).
    public var resolutionBadge: String {
        switch videoHeight {
        case 2000...: return "4K UHD"
        case 1300..<2000: return "1440p QHD"
        case 900..<1300: return "1080p FHD"
        case 600..<900: return "720p HD"
        case 420..<600: return "480p SD"
        case 1..<420: return "360p SD"
        default: return "Adaptive"
        }
    }

    public var dimensionsText: String? {
        guard videoWidth > 0 && videoHeight > 0 else { return nil }
        return "\(videoWidth)×\(videoHeight)"
    }

    public var fpsText: String? {
        guard framesPerSecond >= 1 else { return nil }
        let rounded = (framesPerSecond * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.15 {
            return "\(Int(rounded.rounded())) fps"
        }
        return String(format: "%.1f fps", rounded)
    }

    public var bitrateText: String? {
        guard observedBitrateBitsPerSecond >= 50_000 else { return nil }
        if observedBitrateBitsPerSecond >= 1_000_000 {
            return String(format: "%.1f Mbps", observedBitrateBitsPerSecond / 1_000_000.0)
        }
        return "\(Int((observedBitrateBitsPerSecond / 1_000.0).rounded())) kbps"
    }

    public var compactSummary: String {
        if let bitrateText, videoHeight > 0 {
            return "\(resolutionBadge) · \(bitrateText)"
        }
        if videoHeight > 0 {
            return dynamicRange != "SDR" ? "\(resolutionBadge) · \(dynamicRange)" : resolutionBadge
        }
        if let bitrateText {
            return bitrateText
        }
        return "Adaptive Stream"
    }

    public var fullTechnicalSummary: String {
        var parts: [String] = []
        if let dim = dimensionsText {
            parts.append("\(dim) (\(resolutionBadge))")
        } else {
            parts.append(resolutionBadge)
        }
        parts.append(dynamicRange)
        if let codec = videoCodec { parts.append(codec) }
        if let fps = fpsText { parts.append(fps) }
        if let br = bitrateText { parts.append(br) }
        return parts.joined(separator: " · ")
    }

    public static func shouldFlushForwardBuffer(
        from previousTier: VideoQualityTier?,
        to newTier: VideoQualityTier
    ) -> Bool {
        guard let previousTier, previousTier != newTier else { return false }
        return rank(of: newTier) > rank(of: previousTier)
    }

    public static func rank(of tier: VideoQualityTier) -> Int {
        switch tier {
        case .p360: return 1
        case .p480: return 2
        case .p720: return 3
        case .p1080: return 4
        case .p1440: return 5
        case .p4K, .auto: return 6
        }
    }

    /// Selects the highest available resolution according to priority: 4K > 2K (1440p) > 1080p > 720p > 480p > 360p,
    /// while honoring explicit user tier choice or HLS Auto adaptive mode.
    public static func selectPreferredVariant(
        from variants: [VideoQualityVariant],
        preferredTier: VideoQualityTier? = nil,
        format: VideoStreamFormat = .mp4
    ) -> VideoQualityVariant? {
        guard !variants.isEmpty else { return nil }

        // 1. Exact tier match if explicitly requested (and for non-HLS .auto, pick highest concrete resolution!)
        if let preferredTier {
            if preferredTier == .auto {
                if format == .hls, let autoVar = variants.first(where: { $0.tier == .auto }) {
                    return autoVar
                }
            } else if let exact = variants.first(where: { $0.tier == preferredTier }) {
                return exact
            }
        }

        // 2. Priority fallback: 4K (2160p) -> 2K (1440p) -> 1080p -> 720p -> 480p -> 360p
        let concreteHighest = variants
            .filter { $0.tier != .auto }
            .max { lhs, rhs in
                if lhs.tier.resolutionPriorityRank != rhs.tier.resolutionPriorityRank {
                    return lhs.tier.resolutionPriorityRank < rhs.tier.resolutionPriorityRank
                }
                return (lhs.bandwidthBitsPerSecond ?? 0) < (rhs.bandwidthBitsPerSecond ?? 0)
            }

        return concreteHighest ?? variants.first
    }
}

public enum SourceFailoverPlanner {
    public static func nextFallbackSource(
        afterFailedID failedID: String,
        triedIDs: Set<String>,
        candidates: [VideoSourceDescriptor]
    ) -> VideoSourceDescriptor? {
        candidates.first { candidate in
            candidate.isAvailable
                && candidate.format.isDirectlyPlayable
                && candidate.healthStatus.isHealthyOrUnchecked
                && candidate.id != failedID
                && !triedIDs.contains(candidate.id)
        }
    }
}

public enum AVMediaTrackHelpers {
    public static func codecDisplayName(for fourCC: FourCharCode) -> String? {
        let chars: [Character] = [
            Character(UnicodeScalar((fourCC >> 24) & 0xFF) ?? "?"),
            Character(UnicodeScalar((fourCC >> 16) & 0xFF) ?? "?"),
            Character(UnicodeScalar((fourCC >> 8) & 0xFF) ?? "?"),
            Character(UnicodeScalar(fourCC & 0xFF) ?? "?")
        ]
        let code = String(chars).trimmingCharacters(in: .whitespaces).lowercased()
        switch code {
        case "avc1", "avc3": return "H.264"
        case "hvc1", "hev1": return "HEVC"
        case "dvh1", "dvhe": return "Dolby Vision"
        case "av01": return "AV1"
        case "vp09": return "VP9"
        case "mp4v": return "MPEG-4"
        default: return code.isEmpty ? nil : code.uppercased()
        }
    }

    public static func matchingOption(
        in group: AVMediaSelectionGroup,
        forLanguageCode languageCode: String,
        displayName: String
    ) -> AVMediaSelectionOption? {
        let targetLang = languageCode.lowercased()
        let targetName = displayName.lowercased()
        return group.options.first { opt in
            let optLang = opt.locale?.language.languageCode?.identifier.lowercased() ?? opt.extendedLanguageTag?.lowercased() ?? ""
            return optLang == targetLang && opt.displayName.lowercased().contains(targetName)
        } ?? group.options.first { opt in
            let optLang = opt.locale?.language.languageCode?.identifier.lowercased() ?? opt.extendedLanguageTag?.lowercased() ?? ""
            return optLang == targetLang
        }
    }

    public static func makeTextStyleRules(from style: SubtitleAppearanceStyle) -> [AVTextStyleRule] {
        let fg = rgbaComponents(hex: style.textColorHex, opacity: 1.0)
        let bg = rgbaComponents(hex: style.backgroundColorHex, opacity: style.backgroundOpacity)
        let attrs: [String: Any] = [
            kCMTextMarkupAttribute_ForegroundColorARGB as String: fg,
            kCMTextMarkupAttribute_BackgroundColorARGB as String: bg,
            kCMTextMarkupAttribute_RelativeFontSize as String: (style.fontSize / 18.0) * 100.0
        ]
        return AVTextStyleRule(textMarkupAttributes: attrs).map { [$0] } ?? []
    }

    private static func rgbaComponents(hex: String, opacity: Double) -> [CGFloat] {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        return [
            CGFloat(opacity),
            CGFloat((int >> 16) & 0xFF) / 255.0,
            CGFloat((int >> 8) & 0xFF) / 255.0,
            CGFloat(int & 0xFF) / 255.0
        ]
    }
}
