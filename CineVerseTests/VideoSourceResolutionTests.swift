import Foundation
import SwiftData
import Testing
@testable import CineVerse

private struct StubITunesCatalogService: ITunesCatalogServiceProtocol {
    var stubbedPreviews: [ITunesPreviewMatch] = []

    func topMovies(genreID: Int?, limit: Int) async throws -> [MediaItem] { [] }
    func moviesByCategory(_ category: MediaProjectType, page: Int) async throws -> [MediaItem] { [] }
    func searchMovies(query: String, limit: Int) async throws -> [MediaItem] { [] }
    func lookupDetails(providerID: String) async throws -> MediaItem? { nil }
    func findPlayablePreviews(
        title: String,
        originalTitle: String,
        isEpisodic: Bool,
        seasonNumber: Int?,
        episodeNumber: Int?,
        limit: Int
    ) async -> [ITunesPreviewMatch] {
        Array(stubbedPreviews.prefix(limit))
    }
    func findPlayablePreviewURL(title: String, originalTitle: String, isEpisodic: Bool, episodeNumber: Int?) async -> URL? {
        stubbedPreviews.first?.url
    }
    func openCinemaShowcase() -> [MediaItem] { OpenCinemaLibrary.items }
    func streamURLForOpenCinema(providerID: String) -> (url: URL, format: VideoStreamFormat, label: String)? { nil }
}

private struct StubArchiveService: InternetArchiveServiceProtocol {
    func findPlayableMatch(title: String, originalTitle: String, year: Int, originalLanguage: String) async throws -> InternetArchiveVideoMatch? {
        nil
    }
}

private struct StubWikimediaService: WikimediaCinemaServiceProtocol {
    var stubbedMatch: WikimediaVideoMatch? = nil

    func resolveByFileTitle(_ fileTitle: String, originalLanguage: String) async throws -> WikimediaVideoMatch? {
        stubbedMatch
    }

    func findFullLengthMatch(
        title: String,
        originalTitle: String,
        year: Int,
        expectedDurationMinutes: Int,
        isEpisodic: Bool,
        episodeTitle: String?,
        originalLanguage: String
    ) async throws -> WikimediaVideoMatch? {
        stubbedMatch
    }
}

private final class StubReachabilityHTTPClient: HTTPClient, @unchecked Sendable {
    let statusByHost: [String: Int]
    let contentTypeByHost: [String: String]

    init(statusByHost: [String: Int], contentTypeByHost: [String: String] = [:]) {
        self.statusByHost = statusByHost
        self.contentTypeByHost = contentTypeByHost
    }

    func data(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let host = endpoint.baseURL.host ?? ""
        let code = statusByHost[host] ?? 200
        let contentType = contentTypeByHost[host] ?? "video/mp4"
        guard code < 400 else {
            throw NetworkError.httpStatus(code: code, message: "HTTP \(code)")
        }
        let response = HTTPURLResponse(
            url: endpoint.baseURL,
            statusCode: code,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
        return (Data(), response)
    }

    func decode<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type, decoder: JSONDecoder) async throws -> T {
        throw NetworkError.invalidResponse
    }
}

@Suite("Category 3: Video Source Resolution, Health Verification & Trailer Separation")
struct VideoSourceResolutionTests {
    @Test func parsesStandardWatchShortEmbedShortsAndLiveYouTubeURLs() throws {
        let watchURL = try #require(URL(string: "https://www.youtube.com/watch?v=zSWdZVtXT7E&feature=youtu.be"))
        #expect(EmbeddedTrailerItem.youTubeID(from: watchURL) == "zSWdZVtXT7E")

        let shortURL = try #require(URL(string: "https://youtu.be/aqz-KE-bpKQ"))
        #expect(EmbeddedTrailerItem.youTubeID(from: shortURL) == "aqz-KE-bpKQ")

        let embedURL = try #require(URL(string: "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"))
        #expect(EmbeddedTrailerItem.youTubeID(from: embedURL) == "dQw4w9WgXcQ")

        let shortsURL = try #require(URL(string: "https://m.youtube.com/shorts/AbC_123-xyz"))
        #expect(EmbeddedTrailerItem.youTubeID(from: shortsURL) == "AbC_123-xyz")

        let liveURL = try #require(URL(string: "https://www.youtube.com/live/Live_ID-99"))
        #expect(EmbeddedTrailerItem.youTubeID(from: liveURL) == "Live_ID-99")
    }

    @Test func rejectsNonYouTubeHostsAndScriptInjectionPayloadsInYouTubeID() throws {
        let nonYT = try #require(URL(string: "https://vimeo.com/12345678"))
        #expect(EmbeddedTrailerItem.youTubeID(from: nonYT) == nil)

        let injected = try #require(URL(string: "https://www.youtube.com/watch?v=abc%22%3E%3Cscript%3E"))
        #expect(EmbeddedTrailerItem.youTubeID(from: injected) == nil)

        let overlyLong = try #require(URL(string: "https://youtu.be/abcdefghijklmnopqrstuvwxyz0123456789"))
        #expect(EmbeddedTrailerItem.youTubeID(from: overlyLong) == nil)
    }

    @Test func openStreamProviderReturnsMultipleMirrorsForBigBuckBunny() async throws {
        let provider = OpenStreamSourceProvider(iTunesService: StubITunesCatalogService())
        let bbb = try #require(OpenCinemaLibrary.items.first { $0.id == "opencinema:movie:open-big-buck-bunny" })
        let sources = await provider.sources(for: bbb, episode: nil)

        #expect(sources.count >= 2)
        #expect(sources.allSatisfy { $0.format == .hls && $0.isAvailable })
        #expect(Set(sources.compactMap { $0.playbackURL?.absoluteString }).count == sources.count)
    }

    @Test func openStreamProviderNeverSubstitutesShortITunesTrailersForFullMovies() async {
        let previewURL = URL.constant("https://video-ssl.itunes.apple.com/itunes-assets/sample_trailer.m4v")
        let stub = StubITunesCatalogService(stubbedPreviews: [
            ITunesPreviewMatch(url: previewURL, label: "Official Trailer · Cut 1")
        ])
        let provider = OpenStreamSourceProvider(iTunesService: stub)
        let commercialMovie = MediaItem(
            id: "opencinema:movie:itunes-999",
            externalIDs: [.openCinema: previewURL.absoluteString],
            primarySource: .openCinema,
            projectType: .movie,
            localizedTitle: "Commercial Blockbuster",
            originalTitle: "Commercial Blockbuster",
            synopsis: "",
            releaseYear: 2025,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Action"],
            durationMinutes: 132,
            ratings: MultiSourceRatings(tmdbScore: 8.2),
            trailerURL: previewURL
        )

        let sources = await provider.sources(for: commercialMovie, episode: nil)
        #expect(sources.isEmpty)
    }

    @Test func wikimediaSourceProviderExposes4KWebMAndHardwareQuickTimeStreams() async {
        let match = WikimediaVideoMatch(
            fileTitle: "File:His Girl Friday (1940, SDR).webm",
            durationSeconds: 5518,
            primaryURL: URL.constant("https://upload.wikimedia.org/wikipedia/commons/2/24/His_Girl_Friday.webm"),
            primaryFormat: .webm,
            qualities: [
                VideoQualityVariant(id: "q4k", tier: .p4K, width: 2960, height: 2160, variantStreamURL: URL.constant("https://upload.wikimedia.org/wikipedia/commons/2/24/His_Girl_Friday.webm"), variantFormat: .webm),
                VideoQualityVariant(id: "q360", tier: .p360, width: 480, height: 360, variantStreamURL: URL.constant("https://upload.wikimedia.org/wikipedia/commons/transcoded/His_Girl_Friday.mov"), variantFormat: .mp4)
            ],
            subtitles: [
                SubtitleTrackOption(id: "sub-ru", languageCode: "ru", displayName: "Russian", format: .webVTT, externalURL: URL.constant("https://commons.wikimedia.org/ru.vtt")),
                SubtitleTrackOption(id: "sub-en", languageCode: "en", displayName: "English", format: .webVTT, externalURL: URL.constant("https://commons.wikimedia.org/en.vtt"))
            ],
            originalLanguage: "en"
        )
        let provider = WikimediaSourceProvider(service: StubWikimediaService(stubbedMatch: match))
        let item = MediaItem(
            id: "opencinema:movie:open-his-girl-friday",
            externalIDs: [.openCinema: "wmfile:File:His Girl Friday (1940, SDR).webm"],
            primarySource: .openCinema,
            projectType: .movie,
            localizedTitle: "His Girl Friday",
            originalTitle: "His Girl Friday",
            synopsis: "",
            releaseYear: 1940,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Comedy"],
            durationMinutes: 92,
            ratings: MultiSourceRatings(tmdbScore: 7.9)
        )

        let sources = await provider.sources(for: item, episode: nil)
        #expect(sources.count == 2)
        #expect(sources[0].format == .webm)
        #expect(sources[0].highestQualityLabel == "4K")
        #expect(sources[0].availableSubtitles.count == 2)
        #expect(sources[1].format == .mp4)
    }

    @Test func openStreamProviderIgnoresNonHTTPSAniListExternalIDEntry() async {
        let provider = OpenStreamSourceProvider(iTunesService: StubITunesCatalogService())
        let anime = MediaItem(
            id: "anilist:anime:1",
            externalIDs: [.openCinema: "mal:5114"],
            primarySource: .aniList,
            projectType: .anime,
            localizedTitle: "Test Anime",
            originalTitle: "Test Anime",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "JP",
            originalLanguage: "ja",
            genres: ["Action"],
            durationMinutes: 24,
            ratings: MultiSourceRatings(aniListScore: 9.0)
        )
        let sources = await provider.sources(for: anime, episode: nil)
        #expect(sources.isEmpty)
    }

    @MainActor
    @Test func videoSourceManagerOrdersUserDirectLinksAheadOfOpenStreamsAndOfficialLinks() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let wmMatch = WikimediaVideoMatch(
            fileTitle: "File:Classic.webm",
            durationSeconds: 5400,
            primaryURL: URL.constant("https://upload.wikimedia.org/classic.webm"),
            primaryFormat: .webm,
            qualities: [VideoQualityVariant(id: "1080", tier: .p1080, width: 1920, height: 1080, variantStreamURL: URL.constant("https://upload.wikimedia.org/classic.webm"), variantFormat: .webm)],
            subtitles: [],
            originalLanguage: "en"
        )
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubArchiveService(),
            iTunesService: StubITunesCatalogService(),
            wikimediaService: StubWikimediaService(stubbedMatch: wmMatch)
        )
        let item = MediaItem(
            id: "tmdb:movie:777",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Priority Film",
            originalTitle: "Priority Film",
            synopsis: "",
            releaseYear: 1960,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Drama"],
            durationMinutes: 90,
            ratings: MultiSourceRatings(tmdbScore: 8.1),
            officialPlatformLinks: [
                ExternalOfficialPlatformLink(id: "off-1", siteName: "Apple TV", url: URL.constant("https://tv.apple.com"))
            ]
        )

        manager.addDirectLinkSource(
            mediaID: item.id,
            season: nil,
            episode: nil,
            label: "My Custom 4K HLS",
            url: URL.constant("https://cdn.example.com/custom4k.m3u8")
        )

        let resolved = await manager.resolveSources(for: item, episode: nil)
        #expect(resolved.count == 3)
        #expect(resolved[0].providerID == "direct_link")
        #expect(resolved[1].providerID == "wikimedia_cinema")
        #expect(resolved[2].providerID == "official_services")
    }

    @MainActor
    @Test func sourceHealthVerificationMarksHealthyOnlineAndPrunesDeadURLs() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let httpStub = StubReachabilityHTTPClient(
            statusByHost: ["healthy.example.com": 200, "dead.example.com": 404],
            contentTypeByHost: ["healthy.example.com": "video/mp4", "dead.example.com": "text/html"]
        )
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: httpStub,
            internetArchiveService: StubArchiveService(),
            iTunesService: StubITunesCatalogService(),
            wikimediaService: StubWikimediaService()
        )

        let healthy = VideoSourceDescriptor(
            id: "s-ok",
            providerID: "open_stream",
            providerName: "Healthy CDN",
            sourceDescription: "",
            isAvailable: true,
            format: .mp4,
            playbackURL: URL.constant("https://healthy.example.com/movie.mp4")
        )
        let broken = VideoSourceDescriptor(
            id: "s-404",
            providerID: "open_stream",
            providerName: "Broken CDN",
            sourceDescription: "",
            isAvailable: true,
            format: .mp4,
            playbackURL: URL.constant("https://dead.example.com/missing.mp4")
        )

        let verified = await manager.verifySourcesHealth([broken, healthy])
        #expect(verified.count == 1)
        #expect(verified[0].id == "s-ok")
        if case .online = verified[0].healthStatus {
            #expect(Bool(true))
        } else {
            Issue.record("Expected healthy stream to report .online status")
        }
    }

    @Test func failoverPlannerSelectsNextUntriedDirectlyPlayableMirror() {
        let s1 = VideoSourceDescriptor(id: "s1", providerID: "open_stream", providerName: "Mirror 1", sourceDescription: "", isAvailable: true, format: .hls, playbackURL: URL.constant("https://cdn1.example.com/a.m3u8"))
        let s2 = VideoSourceDescriptor(id: "s2", providerID: "open_stream", providerName: "Mirror 2", sourceDescription: "", isAvailable: true, format: .hls, playbackURL: URL.constant("https://cdn2.example.com/a.m3u8"))
        let s3 = VideoSourceDescriptor(id: "s3", providerID: "official_services", providerName: "Official", sourceDescription: "", isAvailable: true, format: .externalOfficialService, officialServiceURL: URL.constant("https://tv.apple.com"))

        let firstFallback = SourceFailoverPlanner.nextFallbackSource(afterFailedID: "s1", triedIDs: ["s1"], candidates: [s1, s2, s3])
        #expect(firstFallback?.id == "s2")

        let exhausted = SourceFailoverPlanner.nextFallbackSource(afterFailedID: "s2", triedIDs: ["s1", "s2"], candidates: [s1, s2, s3])
        #expect(exhausted == nil)
    }

    @Test func failoverPlannerSkipsUnavailableAndOfflineDescriptors() {
        let dead = VideoSourceDescriptor(id: "s1", providerID: "local_file", providerName: "Missing File", sourceDescription: "", isAvailable: false, format: .localFile)
        let offlineNet = VideoSourceDescriptor(id: "s2", providerID: "open_stream", providerName: "Offline", sourceDescription: "", isAvailable: true, format: .mp4, playbackURL: URL.constant("https://cdn.example.com/bad.mp4"), healthStatus: .offline(reason: "404"))
        let live = VideoSourceDescriptor(id: "s3", providerID: "open_stream", providerName: "Live Stream", sourceDescription: "", isAvailable: true, format: .webm, playbackURL: URL.constant("https://cdn.example.com/v.webm"), healthStatus: .online(latencyMs: 120))

        let picked = SourceFailoverPlanner.nextFallbackSource(afterFailedID: "s0", triedIDs: ["s0"], candidates: [dead, offlineNet, live])
        #expect(picked?.id == "s3")
    }

    @MainActor
    @Test func playbackSetupViewModelIdentifiesUserSourcesAccurately() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let settings = SettingsStore(modelContext: container.mainContext)
        let libRepo = LibraryRepository(modelContext: container.mainContext)
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubArchiveService(),
            iTunesService: StubITunesCatalogService(),
            wikimediaService: StubWikimediaService()
        )
        let vm = PlaybackSetupViewModel(sourceManager: manager, libraryRepository: libRepo, settingsStore: settings)

        let userDesc = VideoSourceDescriptor(id: "direct:\(UUID().uuidString)", providerID: "direct_link", providerName: "User", sourceDescription: "", isAvailable: true, format: .hls)
        let openDesc = VideoSourceDescriptor(id: "openstream:opencinema:movie:open-sintel:0", providerID: "open_stream", providerName: "Open", sourceDescription: "", isAvailable: true, format: .hls)

        #expect(vm.isUserSource(userDesc) == true)
        #expect(vm.isUserSource(openDesc) == false)
    }

    @Test func videoStreamFormatFlagsDirectPlayabilityAndWebMediaSurfaceCorrectly() {
        #expect(VideoStreamFormat.hls.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.mp4.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.webm.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.dash.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.localFile.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.externalOfficialService.isDirectlyPlayable == false)

        #expect(VideoStreamFormat.webm.usesWebMediaSurface == true)
        #expect(VideoStreamFormat.dash.usesWebMediaSurface == true)
        #expect(VideoStreamFormat.hls.usesWebMediaSurface == false)
        #expect(VideoStreamFormat.mp4.usesWebMediaSurface == false)
    }

    @MainActor
    @Test func userDirectLinkCanBeDeletedCleanlyFromVideoSourceManager() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubArchiveService(),
            iTunesService: StubITunesCatalogService(),
            wikimediaService: StubWikimediaService()
        )
        let item = MediaItem(
            id: "tmdb:movie:888",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Deletable",
            originalTitle: "Deletable",
            synopsis: "",
            releaseYear: 2024,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: [],
            durationMinutes: 90,
            ratings: MultiSourceRatings()
        )
        manager.addDirectLinkSource(mediaID: item.id, season: nil, episode: nil, label: "Temp", url: URL.constant("https://cdn.example.com/temp.mp4"))
        let initial = await manager.resolveSources(for: item, episode: nil)
        let added = try #require(initial.first)
        manager.deleteUserSource(descriptorID: added.id)
        let afterDelete = await manager.resolveSources(for: item, episode: nil)
        #expect(afterDelete.isEmpty)
    }
}
