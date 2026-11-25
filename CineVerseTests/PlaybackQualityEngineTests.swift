import Foundation
import CoreGraphics
import Testing
@testable import CineVerse

@Suite("Category 2: Playback Quality, Diagnostics & Picture Presets")
struct PlaybackQualityEngineTests {
    @Test func mapsHeightsToExpectedVideoQualityTiers() {
        #expect(VideoQualityTier.from(height: 180) == .p360)
        #expect(VideoQualityTier.from(height: 360) == .p360)
        #expect(VideoQualityTier.from(height: 480) == .p480)
        #expect(VideoQualityTier.from(height: 576) == .p480)
        #expect(VideoQualityTier.from(height: 720) == .p720)
        #expect(VideoQualityTier.from(height: 1080) == .p1080)
        #expect(VideoQualityTier.from(height: 1440) == .p1440)
        #expect(VideoQualityTier.from(height: 2160) == .p4K)
    }

    @Test func peakBitratesAndResolutionsIncreaseMonotonicallyAcrossCappedTiers() {
        let ordered: [VideoQualityTier] = [.p360, .p480, .p720, .p1080, .p1440, .p4K]
        for idx in 1..<ordered.count {
            let prev = ordered[idx - 1]
            let curr = ordered[idx]
            #expect(curr.preferredPeakBitRate > prev.preferredPeakBitRate)
            #expect(curr.preferredMaximumResolution.height > prev.preferredMaximumResolution.height)
            #expect(curr.preferredMaximumResolution.width > prev.preferredMaximumResolution.width)
        }
    }

    @Test func autoTierLeavesBitrateAndResolutionUnrestricted() {
        #expect(VideoQualityTier.auto.preferredPeakBitRate == 0)
        #expect(VideoQualityTier.auto.preferredMaximumResolution == .zero)
    }

    @Test func detailedQualityLabelIncludesMegabitsWhenBandwidthAvailable() {
        let variantWithBW = VideoQualityVariant(id: "q1", tier: .p1080, bandwidthBitsPerSecond: 6_450_000, width: 1920, height: 1080)
        #expect(variantWithBW.detailedLabel == "1080p Full HD (6.5 Mbps)")

        let variantNoBW = VideoQualityVariant(id: "q2", tier: .p720)
        #expect(variantNoBW.detailedLabel == "720p HD")
    }

    @Test func diagnosticsFormatsResolutionBadgesFromPresentationHeight() {
        #expect(PlaybackQualityDiagnostics(videoWidth: 3840, videoHeight: 2160, observedBitrateBitsPerSecond: 0).resolutionBadge == "4K UHD")
        #expect(PlaybackQualityDiagnostics(videoWidth: 2560, videoHeight: 1440, observedBitrateBitsPerSecond: 0).resolutionBadge == "1440p QHD")
        #expect(PlaybackQualityDiagnostics(videoWidth: 1920, videoHeight: 1080, observedBitrateBitsPerSecond: 0).resolutionBadge == "1080p FHD")
        #expect(PlaybackQualityDiagnostics(videoWidth: 1280, videoHeight: 720, observedBitrateBitsPerSecond: 0).resolutionBadge == "720p HD")
        #expect(PlaybackQualityDiagnostics(videoWidth: 854, videoHeight: 480, observedBitrateBitsPerSecond: 0).resolutionBadge == "480p SD")
        #expect(PlaybackQualityDiagnostics(videoWidth: 640, videoHeight: 356, observedBitrateBitsPerSecond: 0).resolutionBadge == "360p SD")
        #expect(PlaybackQualityDiagnostics.empty.resolutionBadge == "Adaptive")
    }

    @Test func diagnosticsFormatsMbpsAndKbpsBitratesCleanly() {
        let high = PlaybackQualityDiagnostics(videoWidth: 1920, videoHeight: 1080, observedBitrateBitsPerSecond: 5_800_000)
        #expect(high.bitrateText == "5.8 Mbps")
        #expect(high.compactSummary == "1080p FHD · 5.8 Mbps")
        #expect(high.dimensionsText == "1920×1080")

        let low = PlaybackQualityDiagnostics(videoWidth: 640, videoHeight: 360, observedBitrateBitsPerSecond: 780_000)
        #expect(low.bitrateText == "780 kbps")
        #expect(low.compactSummary == "360p SD · 780 kbps")
    }

    @Test func diagnosticsClampsNegativeAndNaNInputsSafely() {
        let diag = PlaybackQualityDiagnostics(videoWidth: -100, videoHeight: -50, observedBitrateBitsPerSecond: .nan)
        #expect(diag.videoWidth == 0)
        #expect(diag.videoHeight == 0)
        #expect(diag.observedBitrateBitsPerSecond == 0)
        #expect(diag.dimensionsText == nil)
        #expect(diag.bitrateText == nil)
        #expect(diag.compactSummary == "Adaptive Stream")
    }

    @Test func detectsUpwardQualitySwitchesRequiringForwardBufferFlush() {
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: .p360, to: .p1080) == true)
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: .p480, to: .p4K) == true)
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: .p720, to: .auto) == true)
    }

    @Test func skipsForwardBufferFlushOnDownwardOrIdenticalQualitySwitch() {
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: .p1080, to: .p480) == false)
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: .p1080, to: .p1080) == false)
        #expect(PlaybackQualityDiagnostics.shouldFlushForwardBuffer(from: nil, to: .p1080) == false)
    }

    @Test func picturePresetsProvideBoundedCalibrationValues() {
        for preset in VideoPicturePreset.allCases {
            #expect(preset.contrast >= 1.0 && preset.contrast <= 1.25)
            #expect(preset.saturation >= 1.0 && preset.saturation <= 1.30)
            #expect(preset.brightness >= -0.05 && preset.brightness <= 0.05)
            #expect(!preset.symbolName.isEmpty)
            #expect(!preset.subtitle.isEmpty)
        }
        #expect(VideoPicturePreset.standard.contrast == 1.0)
        #expect(VideoPicturePreset.standard.saturation == 1.0)
        #expect(VideoPicturePreset.standard.brightness == 0.0)
    }

    @Test func audioTrackFullLabelDistinguishesOriginalFromDubbedTracks() {
        let orig = AudioTrackOption(id: "a1", languageCode: "ja", displayName: "Japanese", voiceoverStudio: "Original Mix", isOriginal: true)
        #expect(orig.fullLabel == "Japanese • Original (Original Mix)")

        let dub = AudioTrackOption(id: "a2", languageCode: "en", displayName: "English", voiceoverStudio: "Studio Dub", isOriginal: false)
        #expect(dub.fullLabel == "English • Studio Dub")
    }

    @MainActor
    @Test func playerEngineUpdatesPlaybackRateWithoutCrashingWhenIdle() {
        let subEngine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        let engine = PlayerEngine(subtitleEngine: subEngine)
        engine.setRate(1.5)
        #expect(engine.playbackRate == 1.5)
        engine.setRate(1.0)
        #expect(engine.playbackRate == 1.0)
        engine.teardown()
    }

    @Test func multiSourceRatingsComputesCompositeAverageIgnoringZeroes() {
        let both = MultiSourceRatings(tmdbScore: 8.0, aniListScore: 9.0, tvMazeScore: 7.0)
        #expect(abs(both.compositeScore - 8.0) < 0.001)
        let empty = MultiSourceRatings()
        #expect(empty.compositeScore == 0)
    }

    @Test func preferredVariantEnforces4KAnd2KPriorityOverLowerResolutions() {
        let variants = [
            VideoQualityVariant(id: "auto", tier: .auto),
            VideoQualityVariant(id: "720", tier: .p720, width: 1280, height: 720),
            VideoQualityVariant(id: "1080", tier: .p1080, width: 1920, height: 1080),
            VideoQualityVariant(id: "1440", tier: .p1440, width: 2560, height: 1440),
            VideoQualityVariant(id: "2160", tier: .p4K, width: 3840, height: 2160)
        ]

        let bestDefault = PlaybackQualityDiagnostics.selectPreferredVariant(from: variants, preferredTier: nil, format: .webm)
        #expect(bestDefault?.tier == .p4K)

        let explicit2K = PlaybackQualityDiagnostics.selectPreferredVariant(from: variants, preferredTier: .p1440, format: .webm)
        #expect(explicit2K?.tier == .p1440)

        let adaptiveHLS = PlaybackQualityDiagnostics.selectPreferredVariant(from: variants, preferredTier: .auto, format: .hls)
        #expect(adaptiveHLS?.tier == .auto)

        let nonHLSAutoPicksHighest = PlaybackQualityDiagnostics.selectPreferredVariant(from: variants, preferredTier: .auto, format: .webm)
        #expect(nonHLSAutoPicksHighest?.tier == .p4K)
    }

    @Test func fullTechnicalSummaryReportsRealDecodedDimensionsCodecFPSAndHDR() {
        let hdr4K = PlaybackQualityDiagnostics(
            videoWidth: 3840,
            videoHeight: 2160,
            observedBitrateBitsPerSecond: 18_400_000,
            framesPerSecond: 24,
            dynamicRange: "Dolby Vision",
            videoCodec: "HEVC"
        )
        #expect(hdr4K.fullTechnicalSummary == "3840×2160 (4K UHD) · Dolby Vision · HEVC · 24 fps · 18.4 Mbps")

        let honestSD = PlaybackQualityDiagnostics(
            videoWidth: 640,
            videoHeight: 360,
            observedBitrateBitsPerSecond: 850_000,
            framesPerSecond: 29.97,
            dynamicRange: "SDR",
            videoCodec: "H.264"
        )
        #expect(honestSD.resolutionBadge == "360p SD")
        #expect(honestSD.fullTechnicalSummary.contains("640×360 (360p SD)"))
        #expect(!honestSD.fullTechnicalSummary.contains("4K"))
    }

    @Test func audioTrackNormalizerNumbersUnnamedDuplicateDubsWithoutInventingStudios() {
        let tracks = [
            AudioTrackOption(id: "orig", languageCode: "ja", displayName: "Japanese", voiceoverStudio: "Original Audio", isOriginal: true),
            AudioTrackOption(id: "ru1", languageCode: "ru", displayName: "Russian", voiceoverStudio: "Russian", isOriginal: false),
            AudioTrackOption(id: "ru2", languageCode: "ru", displayName: "Russian", voiceoverStudio: "Russian", isOriginal: false),
            AudioTrackOption(id: "en1", languageCode: "en", displayName: "English", voiceoverStudio: "English", isOriginal: false)
        ]

        let normalized = AudioTrackNormalizer.normalize(tracks)
        #expect(normalized.count == 4)
        #expect(normalized[0].isOriginal == true)
        #expect(normalized[1].voiceoverStudio == "Russian Dub 1")
        #expect(normalized[2].voiceoverStudio == "Russian Dub 2")
        #expect(normalized[3].voiceoverStudio == "English Dub")
    }
}
