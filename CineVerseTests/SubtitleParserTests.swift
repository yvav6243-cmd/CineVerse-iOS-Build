import Foundation
import Testing
@testable import CineVerse

private final class SubtitleBundleAnchor {}

@Suite("Category 5: Subtitle Parsers & Live Sync Engine")
struct SubtitleParserTests {
    @Test func parsesSRTWithBOMCRLFAndTags() throws {
        let raw = "\u{FEFF}1\r\n00:00:01,500 --> 00:00:04,000\r\n{\\an8}<i>First line</i>\r\nSecond line\r\n\r\n2\r\n00:01:12,250 --> 00:01:15,750\r\nHello, world!\r\n"
        let cues = SubtitleParsers.parseSRT(raw)

        #expect(cues.count == 2)
        #expect(cues[0].startTime == 1.5)
        #expect(cues[0].endTime == 4.0)
        #expect(cues[0].text == "First line\nSecond line")
        #expect(cues[1].startTime == 72.25)
        #expect(cues[1].text == "Hello, world!")
    }

    @Test func parsesSRTFixture() throws {
        let bundle = Bundle(for: SubtitleBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "sample", withExtension: "srt"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let cues = SubtitleParsers.parse(text: text, format: .srt)

        #expect(cues.count == 2)
        #expect(cues[0].text == "First line\nSecond line")
    }

    @Test func parsesWebVTTWithHeadersStylesAndSettings() throws {
        let bundle = Bundle(for: SubtitleBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "sample", withExtension: "vtt"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let cues = SubtitleParsers.parseWebVTT(text)

        #expect(cues.count == 2)
        #expect(cues[0].startTime == 2.5)
        #expect(cues[0].endTime == 6.0)
        #expect(cues[0].text == "Welcome to CineVerse.")
        #expect(cues[1].startTime == 3720.0)
        #expect(cues[1].endTime == 3724.25)
        #expect(cues[1].text == "Final cue line")
    }

    @Test func parsesShortMMSSWebVTTTimestampsWithoutHours() {
        let vtt = """
        WEBVTT

        00:05.000 --> 00:08.500 align:middle
        Short timestamp format cue
        """
        let cues = SubtitleParsers.parseWebVTT(vtt)
        #expect(cues.count == 1)
        #expect(cues.first?.startTime == 5.0)
        #expect(cues.first?.endTime == 8.5)
    }

    @Test func ignoresEmptyAndInvalidCueBlocksGracefully() {
        let broken = """
        1
        invalid --> timestamp
        Should skip

        2
        00:00:10,000 --> 00:00:05,000
        End before start

        3
        00:00:12,000 --> 00:00:15,000
        Valid cue
        """
        let cues = SubtitleParsers.parseSRT(broken)
        #expect(cues.count == 1)
        #expect(cues.first?.text == "Valid cue")
    }

    @MainActor
    @Test func subtitleEngineFindsActiveCueAcrossHundredsOfCuesViaBinarySearch() {
        let engine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        let generated = (0..<300).map { idx in
            let start = Double(idx * 5)
            return SubtitleCue(id: idx, startTime: start, endTime: start + 3.5, text: "Line #\(idx)")
        }
        engine.loadCuesDirectly(generated)

        engine.update(forTime: 252.0)
        #expect(engine.currentText == "Line #50")

        engine.update(forTime: 254.2)
        #expect(engine.currentText == nil)
    }

    @MainActor
    @Test func subtitleEngineJoinsOverlappingSimultaneousSpeakerCues() {
        let engine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        engine.loadCuesDirectly([
            SubtitleCue(id: 1, startTime: 10.0, endTime: 14.0, text: "- Watch out!"),
            SubtitleCue(id: 2, startTime: 11.0, endTime: 13.5, text: "- Hang on!")
        ])
        engine.update(forTime: 12.0)
        #expect(engine.currentText == "- Watch out!\n- Hang on!")
    }

    @MainActor
    @Test func subtitleEngineAppliesPositiveAndNegativeSyncOffsetsCorrectly() {
        let engine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        engine.loadCuesDirectly([
            SubtitleCue(id: 1, startTime: 10.0, endTime: 12.0, text: "Synced Dialogue")
        ])

        // Delay subtitles by +1.5s -> cue [10..12] should appear at video time [11.5..13.5]
        engine.adjustTimingOffset(by: 1.5, currentVideoTime: 10.5)
        #expect(engine.timingOffsetSeconds == 1.5)
        #expect(engine.currentText == nil)

        engine.update(forTime: 12.2)
        #expect(engine.currentText == "Synced Dialogue")

        // Reset offset -> at 12.2s cue [10..12] is already finished
        engine.resetTimingOffset(currentVideoTime: 12.2)
        #expect(engine.timingOffsetSeconds == 0)
        #expect(engine.currentText == nil)
    }

    @MainActor
    @Test func subtitleEngineClampsExtremeTimingOffsetsToTenSeconds() {
        let engine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        engine.adjustTimingOffset(by: 25.0, currentVideoTime: 0)
        #expect(engine.timingOffsetSeconds == 10.0)

        engine.adjustTimingOffset(by: -40.0, currentVideoTime: 0)
        #expect(engine.timingOffsetSeconds == -10.0)
    }

    @MainActor
    @Test func subtitleEngineRejectsInsecureHTTPExternalSubtitleURL() async {
        let engine = SubtitleEngine(httpClient: URLSessionHTTPClient())
        await engine.loadExternal(url: URL.constant("http://cdn.example.com/sub.srt"), format: .srt)
        #expect(engine.loadError != nil)
        #expect(engine.cues.isEmpty)
    }
}
