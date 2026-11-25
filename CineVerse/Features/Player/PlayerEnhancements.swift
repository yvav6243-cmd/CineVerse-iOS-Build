import Foundation
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

    public static let empty = PlaybackQualityDiagnostics(
        videoWidth: 0,
        videoHeight: 0,
        observedBitrateBitsPerSecond: 0
    )

    public init(videoWidth: Int, videoHeight: Int, observedBitrateBitsPerSecond: Double) {
        self.videoWidth = max(0, videoWidth)
        self.videoHeight = max(0, videoHeight)
        self.observedBitrateBitsPerSecond = observedBitrateBitsPerSecond.isFinite
            ? max(0, observedBitrateBitsPerSecond)
            : 0
    }

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
            return resolutionBadge
        }
        if let bitrateText {
            return bitrateText
        }
        return "Adaptive Stream"
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
                && candidate.id != failedID
                && !triedIDs.contains(candidate.id)
        }
    }
}
