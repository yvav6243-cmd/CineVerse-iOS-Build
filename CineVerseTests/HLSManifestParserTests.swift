import Foundation
import Testing
@testable import CineVerse

private final class HLSBundleAnchor {}

@Suite("HLS Manifest Parser")
struct HLSManifestParserTests {
    @Test func parsesVariantsAudioGroupsSubtitlesAndRelativeURIs() throws {
        let bundle = Bundle(for: HLSBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "master", withExtension: "m3u8"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let baseURL = URL.constant("https://cdn.example.com/streams/show/master.m3u8")

        let parsed = HLSManifestParser.parse(
            manifestText: text,
            baseURL: baseURL,
            originalLanguage: "ja"
        )

        // 4 resolution variants + Auto
        #expect(parsed.qualities.count == 5)
        #expect(parsed.qualities.first?.tier == .auto)
        #expect(parsed.qualities.contains(where: { $0.tier == .p4K }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p1080 }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p720 }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p360 }))

        let p1080 = try #require(parsed.qualities.first(where: { $0.tier == .p1080 }))
        #expect(p1080.variantStreamURL?.absoluteString == "https://cdn.example.com/streams/show/video/1080p.m3u8")

        // 3 audio tracks (ja original, ru dub, en dub)
        #expect(parsed.audioTracks.count == 3)
        let jaTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "ja" }))
        #expect(jaTrack.isOriginal == true)
        #expect(jaTrack.dedicatedAudioStreamURL?.absoluteString == "https://cdn.example.com/streams/show/audio/ja/index.m3u8")

        let ruTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "ru" }))
        #expect(ruTrack.isOriginal == false)
        #expect(ruTrack.voiceoverStudio == "AniLibria Russian")

        let enTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "en" }))
        #expect(enTrack.channelCount == 6)

        // 2 subtitle tracks
        #expect(parsed.subtitles.count == 2)
        #expect(parsed.subtitles.first?.format == .embeddedHLS)
    }
}
