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

@Suite("Category 3: Video Source Resolution, YouTube Parsing & Failover")
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

    @Test func openStreamProviderDeduplicatesEmbeddedAndSearchedPreviewURLs() async {
        let duplicateURL = URL.constant("https://video-ssl.itunes.apple.com/itunes-assets/sample1.m4v")
        let uniqueURL = URL.constant("https://video-ssl.itunes.apple.com/itunes-assets/sample2.m4v")
        let stub = StubITunesCatalogService(stubbedPreviews: [
            ITunesPreviewMatch(url: duplicateURL, label: "Official Trailer · Cut 1"),
            ITunesPreviewMatch(url: uniqueURL, label: "Official Trailer · Cut 2")
        ])
        let provider = OpenStreamSourceProvider(iTunesService: stub)
        let movie = MediaItem(
            id: "opencinema:movie:itunes-999",
            externalIDs: [.openCinema: duplicateURL.absoluteString],
            primarySource: .openCinema,
            projectType: .movie,
            localizedTitle: "Sample Film",
            originalTitle: "Sample Film",
            synopsis: "",
            releaseYear: 2025,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Action"],
            durationMinutes: 120,
            ratings: MultiSourceRatings(tmdbScore: 7.9)
        )

        let sources = await provider.sources(for: movie, episode: nil)
        #expect(sources.count == 2)
        #expect(sources[0].providerName == "Official Trailer (Apple)")
        #expect(sources[1].providerName == "Official Trailer · Cut 2")
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
        let stubITunes = StubITunesCatalogService(stubbedPreviews: [
            ITunesPreviewMatch(url: URL.constant("https://video-ssl.itunes.apple.com/preview.m4v"), label: "Official Trailer · Film")
        ])
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubArchiveService(),
            iTunesService: stubITunes
        )
        let item = MediaItem(
            id: "tmdb:movie:777",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Priority Film",
            originalTitle: "Priority Film",
            synopsis: "",
            releaseYear: 2025,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Sci-Fi"],
            durationMinutes: 130,
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
        #expect(resolved[1].providerID == "open_stream")
        #expect(resolved[2].providerID == "official_services")
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

    @Test func failoverPlannerSkipsUnavailableDescriptors() {
        let dead = VideoSourceDescriptor(id: "s1", providerID: "local_file", providerName: "Missing File", sourceDescription: "", isAvailable: false, format: .localFile)
        let live = VideoSourceDescriptor(id: "s2", providerID: "open_stream", providerName: "Live Stream", sourceDescription: "", isAvailable: true, format: .mp4, playbackURL: URL.constant("https://cdn.example.com/v.mp4"))

        let picked = SourceFailoverPlanner.nextFallbackSource(afterFailedID: "s0", triedIDs: ["s0"], candidates: [dead, live])
        #expect(picked?.id == "s2")
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
            iTunesService: StubITunesCatalogService()
        )
        let vm = PlaybackSetupViewModel(sourceManager: manager, libraryRepository: libRepo, settingsStore: settings)

        let userDesc = VideoSourceDescriptor(id: "direct:\(UUID().uuidString)", providerID: "direct_link", providerName: "User", sourceDescription: "", isAvailable: true, format: .hls)
        let openDesc = VideoSourceDescriptor(id: "openstream:opencinema:movie:open-sintel:0", providerID: "open_stream", providerName: "Open", sourceDescription: "", isAvailable: true, format: .hls)

        #expect(vm.isUserSource(userDesc) == true)
        #expect(vm.isUserSource(openDesc) == false)
    }

    @Test func videoStreamFormatFlagsDirectPlayabilityCorrectly() {
        #expect(VideoStreamFormat.hls.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.mp4.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.localFile.isDirectlyPlayable == true)
        #expect(VideoStreamFormat.externalOfficialService.isDirectlyPlayable == false)
    }

    @MainActor
    @Test func userDirectLinkCanBeDeletedCleanlyFromVideoSourceManager() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let manager = VideoSourceManager(
            modelContext: container.mainContext,
            httpClient: URLSessionHTTPClient(),
            internetArchiveService: StubArchiveService(),
            iTunesService: StubITunesCatalogService()
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
