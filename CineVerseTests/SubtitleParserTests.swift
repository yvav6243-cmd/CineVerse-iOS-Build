import Foundation
import Testing
@testable import CineVerse

private final class SubtitleBundleAnchor {}

@Suite("Subtitle Parsers")
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
}
