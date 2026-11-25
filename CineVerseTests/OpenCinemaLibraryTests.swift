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
            #expect(item.releaseYear >= 1920)
            #expect(item.displayRating >= 7.0)
            #expect(item.primarySource == .openCinema)
        }
    }

    @Test func includesFullLength4KAnd1080pFeatureFilmsAndPlayableAnimatedSeries() async throws {
        let ids = Set(OpenCinemaLibrary.items.map(\.id))
        #expect(ids.contains("opencinema:movie:open-his-girl-friday"))
        #expect(ids.contains("opencinema:movie:open-charade-1963"))
        #expect(ids.contains("opencinema:movie:open-night-living-dead"))
        #expect(ids.contains("opencinema:movie:open-gullivers-travels"))
        #expect(ids.contains("opencinema:tv:open-superman-series"))

        let superman = try #require(OpenCinemaLibrary.items.first { $0.id == "opencinema:tv:open-superman-series" })
        #expect(superman.projectType.isEpisodic == true)
        #expect(superman.seasons.count == 1)
        #expect(superman.seasons[0].episodes.count == 4)
        #expect(superman.seasons[0].episodes[0].introStartSeconds == 4)
        #expect(superman.seasons[0].episodes[0].introEndSeconds == 44)

        let service = ITunesCatalogService(httpClient: URLSessionHTTPClient())
        let lookedUpSeries = try await service.lookupDetails(providerID: "open-superman-series")
        #expect(lookedUpSeries?.id == "opencinema:tv:open-superman-series")
    }

    @Test func iTunesServiceExposesOpenCinemaShowcaseAndPrimaryStreamLookup() {
        let service = ITunesCatalogService(httpClient: URLSessionHTTPClient())
        #expect(service.openCinemaShowcase().count == OpenCinemaLibrary.items.count)

        let stream = service.streamURLForOpenCinema(providerID: "open-apple-dolby-showcase")
        #expect(stream != nil)
        #expect(stream?.format == .hls)
    }
}
