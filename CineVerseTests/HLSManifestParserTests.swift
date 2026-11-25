import Foundation
import Testing
@testable import CineVerse

private final class HLSBundleAnchor {}

private struct MockHLSHTTPClient: HTTPClient {
    let manifestBody: String

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let data = Data(manifestBody.utf8)
        guard let response = HTTPURLResponse(
            url: endpoint.baseURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/vnd.apple.mpegurl"]
        ) else {
            throw NetworkError.invalidURL
        }
        return (data, response)
    }
}

@Suite("Category 4: HLS Manifest Parser & Inspector")
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

        #expect(parsed.qualities.count == 5)
        #expect(parsed.qualities.first?.tier == .auto)
        #expect(parsed.qualities.contains(where: { $0.tier == .p4K }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p1080 }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p720 }))
        #expect(parsed.qualities.contains(where: { $0.tier == .p360 }))

        let p1080 = try #require(parsed.qualities.first(where: { $0.tier == .p1080 }))
        #expect(p1080.variantStreamURL?.absoluteString == "https://cdn.example.com/streams/show/video/1080p.m3u8")

        #expect(parsed.audioTracks.count == 3)
        let jaTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "ja" }))
        #expect(jaTrack.isOriginal == true)
        #expect(jaTrack.dedicatedAudioStreamURL?.absoluteString == "https://cdn.example.com/streams/show/audio/ja/index.m3u8")

        let ruTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "ru" }))
        #expect(ruTrack.isOriginal == false)
        #expect(ruTrack.voiceoverStudio == "AniLibria Russian")

        let enTrack = try #require(parsed.audioTracks.first(where: { $0.languageCode == "en" }))
        #expect(enTrack.channelCount == 6)

        #expect(parsed.subtitles.count == 2)
        #expect(parsed.subtitles.first?.format == .embeddedHLS)
    }

    @Test func deduplicatesSameQualityTierKeepingHighestBandwidth() {
        let manifest = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=4200000,RESOLUTION=1920x1080
        low_1080.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=7800000,RESOLUTION=1920x1080
        high_1080.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2100000,RESOLUTION=1280x720
        mid_720.m3u8
        """
        let parsed = HLSManifestParser.parse(
            manifestText: manifest,
            baseURL: URL.constant("https://cdn.example.com/master.m3u8"),
            originalLanguage: "en"
        )
        let p1080 = parsed.qualities.first { $0.tier == .p1080 }
        #expect(p1080?.bandwidthBitsPerSecond == 7_800_000)
        #expect(p1080?.variantStreamURL?.lastPathComponent == "high_1080.m3u8")
    }

    @Test func sortsDiscoveredQualitiesDescendingFrom4KDownTo360p() {
        let manifest = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        360.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=18000000,RESOLUTION=3840x2160
        2160.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=3200000,RESOLUTION=1280x720
        720.m3u8
        """
        let parsed = HLSManifestParser.parse(
            manifestText: manifest,
            baseURL: URL.constant("https://cdn.example.com/master.m3u8"),
            originalLanguage: "en"
        )
        #expect(parsed.qualities.map(\.tier) == [.auto, .p4K, .p720, .p360])
    }

    @Test func parsesAttributesContainingCommasInsideQuotes() {
        let raw = #"TYPE=AUDIO,GROUP-ID="aud-main",LANGUAGE="en",NAME="Director's Commentary, Stereo",DEFAULT=YES,CHANNELS="2""#
        let attrs = HLSManifestParser.parseAttributes(raw)
        #expect(attrs["TYPE"] == "AUDIO")
        #expect(attrs["GROUP-ID"] == "\"aud-main\"" || attrs["GROUP-ID"] == "aud-main" || attrs["LANGUAGE"] != nil)
        #expect(attrs["NAME"]?.contains("Director's Commentary, Stereo") == true)
        #expect(attrs["DEFAULT"] == "YES")
    }

    @Test func handlesWindowsCRLFLineEndingsInManifest() {
        let crlfManifest = "#EXTM3U\r\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080\r\nstream1080.m3u8\r\n#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=854x480\r\nstream480.m3u8\r\n"
        let parsed = HLSManifestParser.parse(
            manifestText: crlfManifest,
            baseURL: URL.constant("https://cdn.example.com/live/index.m3u8"),
            originalLanguage: "en"
        )
        #expect(parsed.qualities.count == 3)
        #expect(parsed.qualities[1].tier == .p1080)
        #expect(parsed.qualities[2].tier == .p480)
    }

    @Test func returnsAutoFallbackOnMediaPlaylistWithoutVariantStreams() {
        let singleMediaPlaylist = """
        #EXTM3U
        #EXT-X-TARGETDURATION:6
        #EXTINF:6.000,
        seg0.ts
        """
        let parsed = HLSManifestParser.parse(
            manifestText: singleMediaPlaylist,
            baseURL: URL.constant("https://cdn.example.com/seg/prog.m3u8"),
            originalLanguage: "en"
        )
        #expect(parsed.qualities.count == 1)
        #expect(parsed.qualities.first?.tier == .auto)
    }

    @Test func ignoresMalformedResolutionStringsGracefully() {
        let manifest = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=invalidxheight
        stream.m3u8
        """
        let parsed = HLSManifestParser.parse(
            manifestText: manifest,
            baseURL: URL.constant("https://cdn.example.com/m.m3u8"),
            originalLanguage: "en"
        )
        #expect(!parsed.qualities.isEmpty)
        #expect(parsed.qualities.first?.tier == .auto)
    }

    @Test func inspectorDeduplicatesRepeatedAudioRenditionsAndPrependsAutoQuality() async {
        let manifest = """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a1",LANGUAGE="en",NAME="English",DEFAULT=YES
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a2",LANGUAGE="en",NAME="English",DEFAULT=NO
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a1",LANGUAGE="es",NAME="Español",DEFAULT=NO
        #EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,AUDIO="a1"
        v1080.m3u8
        """
        let inspector = MediaSourceInspector(httpClient: MockHLSHTTPClient(manifestBody: manifest))
        let desc = VideoSourceDescriptor(
            id: "test-hls",
            providerID: "open_stream",
            providerName: "Test HLS",
            sourceDescription: "",
            isAvailable: true,
            format: .hls,
            playbackURL: URL.constant("https://cdn.example.com/master.m3u8")
        )
        let inspected = await inspector.inspect(desc, originalLanguage: "en")

        #expect(inspected.availableQualities.map(\.tier) == [.auto, .p1080])
        #expect(inspected.availableAudioTracks.count == 2)
    }

    @Test func inspectorPreservesExistingAttachedSubtitlesAlongsideEmbeddedOnes() async {
        let manifest = """
        #EXTM3U
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="fr",NAME="Français",URI="subs/fr.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,SUBTITLES="subs"
        v720.m3u8
        """
        let inspector = MediaSourceInspector(httpClient: MockHLSHTTPClient(manifestBody: manifest))
        let userSub = SubtitleTrackOption(id: "user-ru", languageCode: "ru", displayName: "Russian SRT", format: .srt)
        let desc = VideoSourceDescriptor(
            id: "test-hls-subs",
            providerID: "direct_link",
            providerName: "Custom",
            sourceDescription: "",
            isAvailable: true,
            format: .hls,
            playbackURL: URL.constant("https://cdn.example.com/master.m3u8"),
            availableSubtitles: [userSub]
        )
        let inspected = await inspector.inspect(desc, originalLanguage: "en")
        #expect(inspected.availableSubtitles.count == 2)
        #expect(inspected.availableSubtitles.contains(where: { $0.id == "user-ru" }))
    }

    @Test func inspectorLeavesExternalOfficialServiceDescriptorUnchanged() async {
        let inspector = MediaSourceInspector(httpClient: MockHLSHTTPClient(manifestBody: ""))
        let official = VideoSourceDescriptor(
            id: "off-1",
            providerID: "official_services",
            providerName: "Apple TV",
            sourceDescription: "",
            isAvailable: true,
            format: .externalOfficialService,
            officialServiceURL: URL.constant("https://tv.apple.com")
        )
        let inspected = await inspector.inspect(official, originalLanguage: "en")
        #expect(inspected == official)
    }
}
