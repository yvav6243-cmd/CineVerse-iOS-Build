import Foundation
import CoreGraphics

// MARK: - Video Stream Format

public enum VideoStreamFormat: String, Codable, CaseIterable, Sendable {
    case hls = "HLS (.m3u8)"
    case mp4 = "Direct MP4 / MOV"
    case webm = "WebM HD/4K (.webm)"
    case dash = "MPEG-DASH (.mpd)"
    case localFile = "Local Video File"
    case externalOfficialService = "Official Service Link"

    public var badgeText: String {
        switch self {
        case .hls: return "HLS Adaptive"
        case .mp4: return "MP4 Direct"
        case .webm: return "WebM VP9/4K"
        case .dash: return "DASH Adaptive"
        case .localFile: return "On-Device File"
        case .externalOfficialService: return "Official Platform"
        }
    }

    public var isDirectlyPlayable: Bool {
        switch self {
        case .hls, .mp4, .webm, .dash, .localFile:
            return true
        case .externalOfficialService:
            return false
        }
    }

    public var usesWebMediaSurface: Bool {
        switch self {
        case .webm, .dash:
            return true
        case .hls, .mp4, .localFile, .externalOfficialService:
            return false
        }
    }
}

// MARK: - Source Health Status

public enum SourceHealthStatus: Codable, Hashable, Sendable {
    case unchecked
    case checking
    case online(latencyMs: Int)
    case offline(reason: String)

    public var isHealthyOrUnchecked: Bool {
        switch self {
        case .unchecked, .checking, .online:
            return true
        case .offline:
            return false
        }
    }

    public var badgeLabel: String {
        switch self {
        case .unchecked: return "Ready"
        case .checking: return "Checking..."
        case .online(let ms): return ms > 0 ? "Online · \(ms)ms" : "Verified Online"
        case .offline: return "Unavailable"
        }
    }
}

// MARK: - Video Quality Tier (4K & 2K Priority)

public enum VideoQualityTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case p4K = "4K"
    case p1440 = "1440p"
    case p1080 = "1080p"
    case p720 = "720p"
    case p480 = "480p"
    case p360 = "360p"

    public var id: String { rawValue }

    public var shortBadge: String {
        self == .p1440 ? "2K" : rawValue
    }

    public var displayLabel: String {
        switch self {
        case .auto: return "Auto (Adaptive)"
        case .p4K: return "4K UHD (2160p)"
        case .p1440: return "2K QHD (1440p)"
        case .p1080: return "1080p Full HD"
        case .p720: return "720p HD"
        case .p480: return "480p SD"
        case .p360: return "360p SD"
        }
    }

    /// Priority rank where higher = sharper resolution (4K > 2K > 1080p > 720p > 480p > 360p).
    public var resolutionPriorityRank: Int {
        switch self {
        case .p4K: return 6
        case .p1440: return 5
        case .p1080: return 4
        case .p720: return 3
        case .p480: return 2
        case .p360: return 1
        case .auto: return 0
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
    public let variantFormat: VideoStreamFormat?

    public init(
        id: String,
        tier: VideoQualityTier,
        bandwidthBitsPerSecond: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        variantStreamURL: URL? = nil,
        variantFormat: VideoStreamFormat? = nil
    ) {
        self.id = id
        self.tier = tier
        self.bandwidthBitsPerSecond = bandwidthBitsPerSecond
        self.width = width
        self.height = height
        self.variantStreamURL = variantStreamURL
        self.variantFormat = variantFormat
    }

    public var detailedLabel: String {
        if let bandwidth = bandwidthBitsPerSecond, bandwidth > 0 {
            let mbps = Double(bandwidth) / 1_000_000.0
            return String(format: "%@ (%.1f Mbps)", tier.displayLabel, mbps)
        }
        return tier.displayLabel
    }

    public var resolutionDimensionsText: String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return "\(width)×\(height)"
    }
}

// MARK: - Real Audio Voiceover & Track Option

public enum AudioVoiceoverKind: String, Codable, CaseIterable, Sendable {
    case original = "Original"
    case dub = "Dub"
    case multiVoice = "Multi-Voice"
    case commentary = "Commentary"
}

public struct AudioTrackOption: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let languageCode: String
    public let displayName: String
    public let voiceoverStudio: String
    public let voiceoverKind: AudioVoiceoverKind
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
        voiceoverKind: AudioVoiceoverKind? = nil,
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
        if let voiceoverKind {
            self.voiceoverKind = voiceoverKind
        } else if voiceoverStudio.localizedCaseInsensitiveContains("commentary") {
            self.voiceoverKind = .commentary
        } else if isOriginal {
            self.voiceoverKind = .original
        } else {
            self.voiceoverKind = .dub
        }
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
    public var isAvailable: Bool
    public let format: VideoStreamFormat
    public let playbackURL: URL?
    public let officialServiceURL: URL?
    public var availableQualities: [VideoQualityVariant]
    public var availableAudioTracks: [AudioTrackOption]
    public var availableSubtitles: [SubtitleTrackOption]
    public let episodeID: String?
    public var durationSeconds: TimeInterval?
    public var healthStatus: SourceHealthStatus

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
        episodeID: String? = nil,
        durationSeconds: TimeInterval? = nil,
        healthStatus: SourceHealthStatus = .unchecked
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
        self.durationSeconds = durationSeconds
        self.healthStatus = healthStatus
    }

    public var highestQualityLabel: String {
        let best = availableQualities
            .filter { $0.tier != .auto }
            .max { $0.tier.resolutionPriorityRank < $1.tier.resolutionPriorityRank }
        return best?.tier.rawValue ?? (format == .hls ? "Adaptive HD" : "HD")
    }

    public var audioSummaryLabel: String {
        let langs = Array(Set(availableAudioTracks.map { LanguageCatalog.displayName(forLanguageCode: $0.languageCode) })).sorted()
        if langs.isEmpty { return "Original Audio" }
        if langs.count <= 2 { return langs.joined(separator: ", ") }
        return "\(langs.prefix(2).joined(separator: ", ")) +\(langs.count - 2)"
    }

    public var subtitleSummaryLabel: String {
        if availableSubtitles.isEmpty { return "No Embedded Subs" }
        return "\(availableSubtitles.count) Sub\(availableSubtitles.count == 1 ? "" : "s")"
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
