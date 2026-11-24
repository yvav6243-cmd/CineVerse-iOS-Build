import Foundation
import Testing
@testable import CineVerse

@Suite("Open Cinema Library")
struct OpenCinemaLibraryTests {
    @Test func containsAtLeastEightUniqueFilmsWithHTTPSStreams() {
        let films = OpenCinemaLibrary.films
        #expect(films.count >= 8)

        let ids = films.map(\.item.id)
        #expect(Set(ids).count == films.count)

        for entry in films {
            #expect(!entry.streams.isEmpty)
            for stream in entry.streams {
                #expect(stream.url.scheme?.lowercased() == "https")
            }
        }
    }

    @Test func preservesLegacyOpenCinemaIDs() {
        let ids = Set(OpenCinemaLibrary.items.map(\.id))
        #expect(ids.contains("opencinema:movie:open-tears-of-steel"))
        #expect(ids.contains("opencinema:movie:open-big-buck-bunny"))
        #expect(ids.contains("opencinema:movie:open-apple-dolby-showcase"))
    }
}
