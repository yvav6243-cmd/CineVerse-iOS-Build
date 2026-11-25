import Foundation
import Testing
@testable import CineVerse

@Suite("Category 8: Open Cinema Library & Stream Integrity")
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
                #expect(!stream.label.isEmpty)
                #expect(!stream.note.isEmpty)
            }
        }
    }

    @Test func preservesLegacyOpenCinemaIDs() {
        let ids = Set(OpenCinemaLibrary.items.map(\.id))
        #expect(ids.contains("opencinema:movie:open-tears-of-steel"))
        #expect(ids.contains("opencinema:movie:open-big-buck-bunny"))
        #expect(ids.contains("opencinema:movie:open-apple-dolby-showcase"))
    }

    @Test func includesBlenderOpenFilmsSintelAndElephantsDream() {
        let ids = Set(OpenCinemaLibrary.items.map(\.id))
        #expect(ids.contains("opencinema:movie:open-sintel"))
        #expect(ids.contains("opencinema:movie:open-elephants-dream"))
    }

    @Test func providesMultipleCDNMirrorsForBigBuckBunnyAndElephantsDream() {
        let bbbStreams = OpenCinemaLibrary.streams(forItemID: "opencinema:movie:open-big-buck-bunny")
        let edStreams = OpenCinemaLibrary.streams(forItemID: "opencinema:movie:open-elephants-dream")
        #expect(bbbStreams.count >= 2)
        #expect(edStreams.count >= 2)
    }

    @Test func resolvesStreamsByShortProviderIDOrFullCanonicalID() {
        let byShort = OpenCinemaLibrary.streams(forItemID: "open-sintel")
        let byFull = OpenCinemaLibrary.streams(forItemID: "opencinema:movie:open-sintel")
        #expect(!byShort.isEmpty)
        #expect(byShort == byFull)
    }

    @Test func returnsEmptyStreamsArrayForUnknownItemID() {
        #expect(OpenCinemaLibrary.streams(forItemID: "opencinema:movie:non-existent").isEmpty)
        #expect(OpenCinemaLibrary.streams(forItemID: "itunes-12345").isEmpty)
    }

    @Test func allOpenCinemaItemsCarryPositiveDurationsYearsAndRatings() {
        for item in OpenCinemaLibrary.items {
            #expect(item.durationMinutes > 0)
            #expect(item.releaseYear >= 2000)
            #expect(item.displayRating >= 7.0)
            #expect(item.primarySource == .openCinema)
        }
    }

    @Test func iTunesServiceExposesOpenCinemaShowcaseAndPrimaryStreamLookup() {
        let service = ITunesCatalogService(httpClient: URLSessionHTTPClient())
        #expect(service.openCinemaShowcase().count == OpenCinemaLibrary.items.count)

        let stream = service.streamURLForOpenCinema(providerID: "open-apple-dolby-showcase")
        #expect(stream != nil)
        #expect(stream?.format == .hls)
    }
}
