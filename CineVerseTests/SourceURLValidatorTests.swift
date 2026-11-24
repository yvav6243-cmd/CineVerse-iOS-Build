import Foundation
import Testing
@testable import CineVerse

@Suite("Source URL Validator")
struct SourceURLValidatorTests {
    @Test func rejectsHTTPAndAllowsHTTPS() {
        let httpResult = SourceURLValidator.validateSyntax("http://cdn.example.com/video.mp4")
        #expect(httpResult == .failure(.insecureProtocol))

        let validMP4 = SourceURLValidator.validateSyntax("https://cdn.example.com/movies/film.mp4")
        #expect(validMP4 == .success(URL.constant("https://cdn.example.com/movies/film.mp4")))

        let validHLS = SourceURLValidator.validateSyntax("https://cdn.example.com/live/master.m3u8?token=abc")
        #expect(validHLS == .success(URL.constant("https://cdn.example.com/live/master.m3u8?token=abc")))
    }

    @Test func rejectsExecutablesCredentialsAndPrivateHosts() {
        #expect(SourceURLValidator.validateSyntax("https://evil.example.com/payload.exe") == .failure(.forbiddenFileType("exe")))
        #expect(SourceURLValidator.validateSyntax("https://evil.example.com/app.ipa") == .failure(.forbiddenFileType("ipa")))
        #expect(SourceURLValidator.validateSyntax("https://user:pass@cdn.example.com/video.mp4") == .failure(.embeddedCredentials))
        #expect(SourceURLValidator.validateSyntax("https://192.168.1.25/video.mp4") == .failure(.privateOrLocalHost))
        #expect(SourceURLValidator.validateSyntax("https://localhost/stream.m3u8") == .failure(.privateOrLocalHost))
    }

    @Test func validatesSubtitleURLs() {
        #expect(SourceURLValidator.validateSubtitleSyntax("https://cdn.example.com/subs/en.vtt") == .success(URL.constant("https://cdn.example.com/subs/en.vtt")))
        #expect(SourceURLValidator.validateSubtitleSyntax("http://cdn.example.com/subs/en.srt") == .failure(.insecureProtocol))
        #expect(SourceURLValidator.validateSubtitleSyntax("https://cdn.example.com/subs/bad.zip") == .failure(.forbiddenFileType("zip")))
    }
}
