import Foundation
import CoreGraphics

// MARK: - Video Stream Format

public enum VideoStreamFormat: String, Codable, CaseIterable, Sendable {
    case hls = "HLS (.m3u8)"
    case mp4 = "Direct MP4"
    case localFile = "Local Video File"
    case externalOfficialService = "Official Service Link"

    public var badgeText: String {
        switch self {
        case .hls: return "HLS Adaptive"
        case .mp4: return "MP4 Direct"
        case .localFile: return "On-Device File"
        case .externalOfficialService: return "Official Platform"
        }
    }

    public var isDirectlyPlayable: Bool {
        switch self {
        case .hls, .mp4, .localFile:
            return true
        case .externalOfficialService:
            return false
        }
    }
}

// MARK: - Video Quality Tier

public enum VideoQualityTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case p360 = "360p"
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"
    case p1440 = "1440p"
    case p4K = "4K"

    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .auto: return "Auto (Adaptive)"
        case .p360: return "360p SD"
        case .p480: return "480p SD"
        case .p720: return "720p HD"
        case .p1080: return "1080p Full HD"
        case .p1440: return "1440p QHD"
        case .p4K: return "4K Ultra HD"
        }
    }

    public var preferredMaximumResolution: CGSize {
        switch self {
        case .auto: return .zero
        case .p360: return CGSize(width: 640, height: 360)
        case .p480: return CGSize(width: 854, height: 480)
        case .p720: return CGSize(width: 1280, height: 720)
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p1440: return CGSize(width: 2560, height: 1440)
        case .p4K: return CGSize(width: 3840, height: 2160)
        }
    }

    public var preferredPeakBitRate: Double {
        switch self {
        case .auto: return 0
        case .p360: return 900_000
        case .p480: return 1_600_000
        case .p720: return 3_500_000
        case .p1080: return 6_800_000
        case .p1440: return 12_500_000
        case .p4K: return 24_000_000
        }
    }

    public static func from(height: Int) -> VideoQualityTier {
        switch height {
        case ..<400: return .p360
        case 400..<600: return .p480
        case 600..<900: return .p720
        case 900..<1300: return .p1080
        case 1300..<1800: return .p1440
        default: return .p4K
        }
    }
}

public struct VideoQualityVariant: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let tier: VideoQualityTier
    public let bandwidthBitsPerSecond: Int?
    public let width: Int?
    public let height: Int?
    public let variantStreamURL: URL?

    public init(
        id: String,
        tier: VideoQualityTier,
        bandwidthBitsPerSecond: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        variantStreamURL: URL? = nil
    ) {
        self.id = id
        self.tier = tier
        self.bandwidthBitsPerSecond = bandwidthBitsPerSecond
        self.width = width
        self.height = height
        self.variantStreamURL = variantStreamURL
    }

    public var detailedLabel: String {
        if let bandwidth = bandwidthBitsPerSecond, bandwidth > 0 {
            let mbps = Double(bandwidth) / 1_000_000.0
            return String(format: "%@ (%.1f Mbps)", tier.displayLabel, mbps)
        }
        return tier.displayLabel
    }
}

// MARK: - Real Audio Track / Voiceover Option

public struct AudioTrackOption: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let languageCode: String
    public let displayName: String
    public let voiceoverStudio: String
    public let isOriginal: Bool
    public let isDefault: Bool
    public let hlsGroupID: String?
    public let dedicatedAudioStreamURL: URL?
    public let alternateMuxedVideoURL: URL?
    public let channelCount: Int

    public init(
        id: String,
        languageCode: String,
        displayName: String,
        voiceoverStudio: String,
        isOriginal: Bool = false,
        isDefault: Bool = false,
        hlsGroupID: String? = nil,
        dedicatedAudioStreamURL: URL? = nil,
        alternateMuxedVideoURL: URL? = nil,
        channelCount: Int = 2
    ) {
        self.id = id
        self.languageCode = languageCode
        self.displayName = displayName
        self.voiceoverStudio = voiceoverStudio
        self.isOriginal = isOriginal
        self.isDefault = isDefault
        self.hlsGroupID = hlsGroupID
        self.dedicatedAudioStreamURL = dedicatedAudioStreamURL
        self.alternateMuxedVideoURL = alternateMuxedVideoURL
        self.channelCount = channelCount
    }

    public var fullLabel: String {
        if isOriginal {
            return "\(displayName) • Original (\(voiceoverStudio))"
        }
        return "\(displayName) • \(voiceoverStudio)"
    }
}

// MARK: - Subtitle Track & Styling

public enum SubtitleFormat: String, Codable, CaseIterable, Sendable {
    case srt = "SRT"
    case webVTT = "WebVTT"
    case embeddedHLS = "Embedded HLS/AV"
}

public struct SubtitleTrackOption: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let languageCode: String
    public let displayName: String
    public let format: SubtitleFormat
    public let externalURL: URL?
    public let isDefault: Bool

    public init(
        id: String,
        languageCode: String,
        displayName: String,
        format: SubtitleFormat,
        externalURL: URL? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.languageCode = languageCode
        self.displayName = displayName
        self.format = format
        self.externalURL = externalURL
        self.isDefault = isDefault
    }
}

public struct SubtitleCue: Identifiable, Hashable, Sendable {
    public let id: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(id: Int, startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

public struct SubtitleAppearanceStyle: Codable, Hashable, Sendable {
    public var fontSize: CGFloat
    public var textColorHex: String
    public var backgroundColorHex: String
    public var backgroundOpacity: Double

    public init(
        fontSize: CGFloat = 18,
        textColorHex: String = "#FFFFFF",
        backgroundColorHex: String = "#000000",
        backgroundOpacity: Double = 0.65
    ) {
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.backgroundOpacity = backgroundOpacity
    }
}

// MARK: - Video Source Descriptor

public struct VideoSourceDescriptor: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let providerID: String
    public let providerName: String
    public let sourceDescription: String
    public let isAvailable: Bool
    public let format: VideoStreamFormat
    public let playbackURL: URL?
    public let officialServiceURL: URL?
    public var availableQualities: [VideoQualityVariant]
    public var availableAudioTracks: [AudioTrackOption]
    public var availableSubtitles: [SubtitleTrackOption]
    public let episodeID: String?

    public init(
        id: String,
        providerID: String,
        providerName: String,
        sourceDescription: String,
        isAvailable: Bool,
        format: VideoStreamFormat,
        playbackURL: URL? = nil,
        officialServiceURL: URL? = nil,
        availableQualities: [VideoQualityVariant] = [],
        availableAudioTracks: [AudioTrackOption] = [],
        availableSubtitles: [SubtitleTrackOption] = [],
        episodeID: String? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.providerName = providerName
        self.sourceDescription = sourceDescription
        self.isAvailable = isAvailable
        self.format = format
        self.playbackURL = playbackURL
        self.officialServiceURL = officialServiceURL
        self.availableQualities = availableQualities
        self.availableAudioTracks = availableAudioTracks
        self.availableSubtitles = availableSubtitles
        self.episodeID = episodeID
    }
}

// MARK: - Pre-Watch Playback Configuration

public struct PreWatchPlaybackSelection: Identifiable, Hashable, Sendable {
    public let id: String
    public let mediaItem: MediaItem
    public let episode: MediaEpisode?
    public let source: VideoSourceDescriptor
    public var selectedQuality: VideoQualityVariant
    public var selectedAudioTrack: AudioTrackOption
    public var selectedSubtitleTrack: SubtitleTrackOption?
    public var startPositionSeconds: TimeInterval

    public init(
        id: String = UUID().uuidString,
        mediaItem: MediaItem,
        episode: MediaEpisode? = nil,
        source: VideoSourceDescriptor,
        selectedQuality: VideoQualityVariant,
        selectedAudioTrack: AudioTrackOption,
        selectedSubtitleTrack: SubtitleTrackOption? = nil,
        startPositionSeconds: TimeInterval = 0
    ) {
        self.id = id
        self.mediaItem = mediaItem
        self.episode = episode
        self.source = source
        self.selectedQuality = selectedQuality
        self.selectedAudioTrack = selectedAudioTrack
        self.selectedSubtitleTrack = selectedSubtitleTrack
        self.startPositionSeconds = startPositionSeconds
    }
}
