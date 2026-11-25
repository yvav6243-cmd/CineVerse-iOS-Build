import Foundation
import SwiftData
import Testing
@testable import CineVerse

private final class StubUniversalHTTPClient: HTTPClient, @unchecked Sendable {
    private let responder: @Sendable (Endpoint) throws -> (Data, Int)

    init(responder: @escaping @Sendable (Endpoint) throws -> (Data, Int)) {
        self.responder = responder
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let (data, _) = try responder(endpoint)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func data(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let (data, code) = try responder(endpoint)
        let resp = HTTPURLResponse(url: endpoint.baseURL, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (data, resp)
    }
}

private struct StubEmptyArchiveService: InternetArchiveServiceProtocol {
    func findPlayableMatch(title: String, originalTitle: String, year: Int, originalLanguage: String) async throws -> InternetArchiveVideoMatch? { nil }
}

private struct StubEmptyITunesService: ITunesCatalogServiceProtocol {
    func topMovies(genreID: Int?, limit: Int) async throws -> [MediaItem] { [] }
    func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem] { [] }
    func searchMovies(query: String, limit: Int) async throws -> [MediaItem] { [] }
    func lookupDetails(providerID: String) async throws -> MediaItem? { nil }
    func findPlayablePreviews(title: String, originalTitle: String, isEpisodic: Bool, seasonNumber: Int?, episodeNumber: Int?, limit: Int) async -> [ITunesPreviewMatch] { [] }
    func findPlayablePreviewURL(title: String, originalTitle: String, isEpisodic: Bool, episodeNumber: Int?) async -> URL? { nil }
    func openCinemaShowcase() -> [MediaItem] { OpenCinemaLibrary.items }
    func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)? { nil }
}

private struct StubEmptyWikimediaService: WikimediaCinemaServiceProtocol {
    func resolveByFileTitle(_ fileTitle: String, originalLanguage: String) async throws -> WikimediaVideoMatch? { nil }
    func findFullLengthMatch(title: String, originalTitle: String, year: Int, expectedDurationMinutes: Int, isEpisodic: Bool, episodeTitle: String?, originalLanguage: String) async throws -> WikimediaVideoMatch? { nil }
}

@Suite("Category 13: Universal Catalog, Availability Statuses & Multi-Source Expansion")
struct UniversalCatalogAndSourcesTests {
    private func sampleItem(
        id: String = "tmdb:movie:999",
        externalIDs: [MetadataProviderSource: String] = [:],
        source: MetadataProviderSource = .tmdb,
        type: MediaProjectType = .movie,
        status: MediaReleaseStatus = .finished,
        releaseDate: Date? = nil,
        releaseYear: Int = 2023,
        trailerURL: URL? = nil,
        officialLinks: [ExternalOfficialPlatformLink] = []
    ) -> MediaItem {
        MediaItem(
            id: id,
            externalIDs: externalIDs,
            primarySource: source,
            projectType: type,
            localizedTitle: "Universal Test Film",
            originalTitle: "Universal Test Film",
            synopsis: "Test synopsis",
            releaseYear: releaseYear,
            releaseDate: releaseDate,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Drama"],
            durationMinutes: 95,
            releaseStatus: status,
            ratings: MultiSourceRatings(tmdbScore: 7.5),
            trailerURL: trailerURL,
            officialPlatformLinks: officialLinks
        )
    }

    @Test func availabilityResolverProducesAllEightStatusesHonestlyWithoutFakingWatch() {
        let now = Date()
        let baseItem = sampleItem()

        // 1. Available to Watch (open HLS stream)
        let hlsSource = VideoSourceDescriptor(
            id: "open-1", providerID: "open_stream", providerName: "Open HLS", sourceDescription: "", isAvailable: true, format: .hls,
            playbackURL: URL.constant("https://example.com/master.m3u8"),
            availableQualities: [VideoQualityVariant(id: "q4k", tier: .p4K, width: 3840, height: 2160)],
            availableAudioTracks: [AudioTrackOption(id: "a1", languageCode: "en", displayName: "English", voiceoverStudio: "Original", isOriginal: true)]
        )
        let avail = ContentAvailabilityResolver.resolve(item: baseItem, sources: [hlsSource], now: now)
        #expect(avail.status == .availableToWatch)
        #expect(avail.canWatchInApp == true)
        #expect(avail.highestQualityLabel == "4K")
        #expect(avail.audioLanguages == ["English"])

        // 2. Public Domain (Internet Archive / Wikimedia)
        let pdSource = VideoSourceDescriptor(
            id: "ia-1", providerID: "internet_archive", providerName: "Internet Archive", sourceDescription: "", isAvailable: true, format: .mp4,
            playbackURL: URL.constant("https://archive.org/download/test/film.mp4")
        )
        let pd = ContentAvailabilityResolver.resolve(item: baseItem, sources: [pdSource], now: now)
        #expect(pd.status == .publicDomain)
        #expect(pd.canWatchInApp == true)

        // 3. User Provided (local file / custom URL)
        let userSource = VideoSourceDescriptor(
            id: "dir-1", providerID: "direct_link", providerName: "Custom", sourceDescription: "", isAvailable: true, format: .mp4,
            playbackURL: URL.constant("https://mycdn.example.com/movie.mp4")
        )
        let usr = ContentAvailabilityResolver.resolve(item: baseItem, sources: [userSource], now: now)
        #expect(usr.status == .userProvided)
        #expect(usr.canWatchInApp == true)

        // 4. Official Streaming (external link only — NEVER watches in app)
        let offSource = VideoSourceDescriptor(
            id: "off-1", providerID: "official_services", providerName: "Netflix", sourceDescription: "", isAvailable: true, format: .externalOfficialService,
            officialServiceURL: URL.constant("https://netflix.com/title/1")
        )
        let off = ContentAvailabilityResolver.resolve(item: baseItem, sources: [offSource], now: now)
        #expect(off.status == .officialStreaming)
        #expect(off.canWatchInApp == false)

        // 5. Coming Soon (within 180 days)
        let soonDate = now.addingTimeInterval(30 * 86_400)
        let soon = ContentAvailabilityResolver.resolve(item: sampleItem(status: .upcoming, releaseDate: soonDate, releaseYear: 2026), sources: [], now: now)
        #expect(soon.status == .comingSoon)
        #expect(soon.canWatchInApp == false)

        // 6. Not Yet Released (distant future or no near release date)
        let farDate = now.addingTimeInterval(400 * 86_400)
        let unreleased = ContentAvailabilityResolver.resolve(item: sampleItem(status: .upcoming, releaseDate: farDate, releaseYear: 2028), sources: [], now: now)
        #expect(unreleased.status == .notYetReleased)
        #expect(unreleased.canWatchInApp == false)

        // 7. Trailer Only (never substituted as full film)
        let trailer = ContentAvailabilityResolver.resolve(item: sampleItem(trailerURL: URL.constant("https://youtube.com/watch?v=dQw4w9WgXcQ")), sources: [], now: now)
        #expect(trailer.status == .trailerOnly)
        #expect(trailer.canWatchInApp == false)

        // 8. Information Only
        let info = ContentAvailabilityResolver.resolve(item: baseItem, sources: [], now: now)
        #expect(info.status == .informationOnly)
        #expect(info.canWatchInApp == false)
    }

    @Test func internetArchiveServiceDecodesBrowseSearchAndIdentifierSources() async throws {
        let searchJSON = """
        {
          "response": {
            "docs": [
              {
                "identifier": "detour-1945",
                "title": "Detour",
                "year": "1945",
                "description": "Classic noir road movie.",
                "creator": "Edgar G. Ulmer",
                "subject": ["Film Noir", "Feature Films"],
                "collection": ["feature_films"],
                "runtime": "68",
                "downloads": 95000
              }
            ]
          }
        }
        """
        let metaJSON = """
        {
          "metadata": {
            "title": "Detour",
            "description": "Classic public domain noir film.",
            "creator": "Edgar G. Ulmer",
            "year": "1945",
            "runtime": "01:08:00",
            "language": "eng",
            "collection": ["feature_films"]
          },
          "files": [
            { "name": "Detour_1080p.mp4", "format": "h.264", "width": "1920", "height": "1080", "length": "4080" },
            { "name": "Detour_en.vtt", "format": "Web Video Text Tracks" }
          ]
        }
        """
        let client = StubUniversalHTTPClient { ep in
            if ep.path.hasPrefix("advancedsearch") {
                return (Data(searchJSON.utf8), 200)
            }
            return (Data(metaJSON.utf8), 200)
        }
        let service = InternetArchiveService(httpClient: client)

        let browsed = try await service.browseCatalog(category: .movie, page: 1, limit: 10)
        #expect(browsed.count == 1)
        #expect(browsed[0].primarySource == .internetArchive)
        #expect(browsed[0].externalIDs[.internetArchive] == "detour-1945")
        #expect(browsed[0].reference?.shareURL?.absoluteString == "https://archive.org/details/detour-1945")

        let match = try await service.findPlayableByIdentifier("detour-1945", originalLanguage: "en")
        #expect(match?.primaryPlaybackURL.absoluteString == "https://archive.org/download/detour-1945/Detour_1080p.mp4")
        #expect(match?.qualities.first?.tier == .p1080)
        #expect(match?.subtitles.count == 1)
    }

    @Test func wikidataMapperBuildsGlobalCatalogEntriesAndDetectsUpcomingReleases() throws {
        let entityJSON = """
        {
          "id": "Q123456",
          "labels": { "en": { "value": "Festival Horizon" } },
          "descriptions": { "en": { "value": "2027 independent short film" } },
          "aliases": { "en": [{ "value": "Horizon Cut" }] },
          "claims": {
            "P577": [{ "mainsnak": { "datavalue": { "type": "time", "value": { "time": "+2027-09-10T00:00:00Z" } } } }],
            "P2047": [{ "mainsnak": { "datavalue": { "type": "quantity", "value": { "amount": "+24" } } } }],
            "P724": [{ "mainsnak": { "datavalue": { "type": "string", "value": "festival-horizon-2027" } } }]
          }
        }
        """
        let dto = try JSONDecoder().decode(WikidataEntityDTO.self, from: Data(entityJSON.utf8))
        let item = try #require(WikidataMapper.mapEntity(dto, preferredLanguage: "en"))
        #expect(item.primarySource == .wikidata)
        #expect(item.projectType == .shortFilm)
        #expect(item.releaseStatus == .upcoming)
        #expect(item.durationMinutes == 24)
        #expect(item.externalIDs[.internetArchive] == "festival-horizon-2027")
    }

    @Test func mediaMergerMergesAcrossAllCatalogSourcesWithoutDuplicates() {
        let wd = sampleItem(id: "wikidata:movie:Q55", externalIDs: [.wikidata: "Q55"], source: .wikidata, type: .movie, trailerURL: nil)
        var tmdb = sampleItem(id: "tmdb:movie:55", externalIDs: [.tmdb: "55"], source: .tmdb, type: .movie, trailerURL: URL.constant("https://youtube.com/watch?v=12345678901"))
        let ia = MediaItem(
            id: "archive:movie:universal-test",
            externalIDs: [.internetArchive: "universal-test"],
            primarySource: .internetArchive,
            projectType: .movie,
            localizedTitle: "Universal Test Film",
            originalTitle: "Universal Test Film",
            synopsis: "Detailed Internet Archive public domain master description that is much longer.",
            releaseYear: 2023,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Classic"],
            durationMinutes: 95,
            ratings: MultiSourceRatings(),
            posterURL: URL.constant("https://archive.org/services/img/universal-test")
        )
        tmdb.alternativeTitles = ["Alt Name"]

        let merged = MediaMerger.merge([wd, ia, tmdb])
        #expect(merged.count == 1)
        #expect(merged[0].primarySource == .tmdb)
        #expect(merged[0].externalIDs[.internetArchive] == "universal-test")
        #expect(merged[0].externalIDs[.wikidata] == "Q55")
        #expect(merged[0].posterURL != nil)
        #expect(merged[0].trailerURL != nil)
    }

    @Test func peerTubeServiceFiltersOutTrailersAndResolvesDirectHLS() async throws {
        let sepiaJSON = """
        {
          "data": [
            { "uuid": "bad-1", "name": "Film Official Trailer", "duration": 180, "account": { "host": "peertube.example.org" } },
            { "uuid": "good-1", "name": "Sintel Open Cinema", "duration": 888, "account": { "host": "peertube.example.org" } }
          ]
        }
        """
        let detailJSON = """
        {
          "duration": 888,
          "streamingPlaylists": [
            { "playlistUrl": "https://peertube.example.org/static/streaming-playlists/hls/good-1/master.m3u8" }
          ],
          "files": []
        }
        """
        let client = StubUniversalHTTPClient { ep in
            if ep.path.contains("api/v1/search/videos") {
                return (Data(sepiaJSON.utf8), 200)
            }
            return (Data(detailJSON.utf8), 200)
        }
        let service = PeerTubeCatalogService(httpClient: client)
        let match = try await service.findPlayableMatch(title: "Sintel Open Cinema", originalTitle: "Sintel Open Cinema", expectedDurationMinutes: 15, isShort: true)
        #expect(match?.uuid == "good-1")
        #expect(match?.format == .hls)
        #expect(match?.playbackURL.absoluteString.hasSuffix(".m3u8") == true)
    }

    @MainActor
    @Test func videoSourceManagerTracksUserSourcesAndRespectsProviderToggles() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let stubHTTP = StubUniversalHTTPClient { _ in (Data(#"{"data":[]}"#.utf8), 200) }
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: stubHTTP,
            internetArchiveService: StubEmptyArchiveService(),
            iTunesService: StubEmptyITunesService(),
            wikimediaService: StubEmptyWikimediaService()
        )
        let item = sampleItem(id: "tmdb:movie:321")
        manager.addDirectLinkSource(
            mediaID: item.id,
            season: nil,
            episode: nil,
            label: "User 1080p",
            url: URL.constant("https://cdn.example.com/movie.m3u8")
        )
        #expect(manager.allUserPlayableMediaIDs().contains(item.id))

        let (_, summary) = await manager.resolveAvailability(for: item, episode: nil)
        #expect(summary.status == .userProvided)
        #expect(summary.canWatchInApp == true)

        SourceProviderPreferences.setEnabled(false, for: "open_stream")
        defer { SourceProviderPreferences.setEnabled(true, for: "open_stream") }
        let openItem = try #require(OpenCinemaLibrary.items.first)
        let disabledSources = await manager.resolveSources(for: openItem, episode: nil)
        #expect(disabledSources.filter { $0.providerID == "open_stream" }.isEmpty)
    }

    @Test func availabilityStatusFilterMatchesCorrectSubsetInEvaluator() {
        let userOwned = sampleItem(id: "tmdb:movie:1")
        let trailerOnly = sampleItem(id: "tmdb:movie:2", trailerURL: URL.constant("https://youtube.com/watch?v=abcdef12345"))
        let upcoming = sampleItem(id: "tmdb:movie:3", status: .upcoming, releaseDate: Date().addingTimeInterval(20 * 86_400), releaseYear: 2026)

        var criteria = CatalogFilterCriteria()
        criteria.availabilityStatus = .trailerOnly
        let matches = CatalogQueryPlanner.postFilterAndSort(
            items: [userOwned, trailerOnly, upcoming],
            criteria: criteria,
            userPlayableMediaIDs: [userOwned.id]
        )
        #expect(matches.map(\.id) == [trailerOnly.id])
    }
}
