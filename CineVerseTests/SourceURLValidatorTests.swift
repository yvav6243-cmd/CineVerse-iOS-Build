import Foundation
import Testing
@testable import CineVerse

@Suite("Category 10A: Security & Source URL Validation")
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

    @Test func blocksFullSSRFPrivateIPv4AndIPv6Ranges() {
        #expect(SourceURLValidator.isPrivateOrLocalHost("127.0.0.1") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("10.0.0.12") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("172.16.0.1") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("172.31.255.254") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("172.32.0.1") == false)
        #expect(SourceURLValidator.isPrivateOrLocalHost("169.254.169.254") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("media-server.local") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("[::1]") == true)
        #expect(SourceURLValidator.isPrivateOrLocalHost("cdn.example.com") == false)
    }

    @Test func rejectsEmptyAndOverlongURLInputs() {
        #expect(SourceURLValidator.validateSyntax("   ") == .failure(.emptyInput))
        let huge = "https://cdn.example.com/" + String(repeating: "a", count: 2100) + ".mp4"
        #expect(SourceURLValidator.validateSyntax(huge) == .failure(.tooLong))
    }

    @Test func rejectsUnsupportedDocumentAndImageExtensionsForVideoStreams() {
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/file.pdf") == .failure(.unsupportedMediaType(".pdf")))
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/photo.png") == .failure(.unsupportedMediaType(".png")))
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/clip.m4v").map { $0.pathExtension } == .success("m4v"))
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/clip.mov").map { $0.pathExtension } == .success("mov"))
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/uhd.webm").map { $0.pathExtension } == .success("webm"))
        #expect(SourceURLValidator.validateSyntax("https://cdn.example.com/manifest.mpd").map { $0.pathExtension } == .success("mpd"))
    }
}
