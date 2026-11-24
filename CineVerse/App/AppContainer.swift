import Foundation
import SwiftData
import Observation

@MainActor
@Observable
public final class AppContainer {
    public let modelContainer: ModelContainer
    public let networkMonitor: NetworkMonitor
    public let httpClient: HTTPClient
    public let responseCache: ResponseDiskCache

    public let tmdbService: TMDBServiceProtocol
    public let aniListService: AniListServiceProtocol
    public let tvMazeService: TVMazeServiceProtocol
    public let jikanService: JikanServiceProtocol
    public let iTunesService: ITunesCatalogServiceProtocol
    public let internetArchiveService: InternetArchiveServiceProtocol

    public let catalogRepository: CatalogRepositoryProtocol
    public let detailsRepository: DetailsRepositoryProtocol
    public let calendarRepository: CalendarRepositoryProtocol
    public let libraryRepository: LibraryRepositoryProtocol
    public let progressRepository: ProgressRepositoryProtocol
    public let collectionsRepository: CollectionsRepositoryProtocol
    public let searchHistoryRepository: SearchHistoryRepositoryProtocol

    public let settingsStore: SettingsStore
    public let sourceManager: VideoSourceManager
    public let trackerService: TrackerService
    public let recommendationEngine: RecommendationEngine
    public let alertScheduler: EpisodeAlertScheduler
    public let widgetWriter: WidgetSnapshotWriter
    public let coordinator = AppCoordinator()

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext

        self.networkMonitor = NetworkMonitor()
        self.httpClient = URLSessionHTTPClient()
        self.responseCache = ResponseDiskCache()

        self.tmdbService = TMDBService(httpClient: httpClient)
        self.aniListService = AniListService(httpClient: httpClient)
        self.tvMazeService = TVMazeService(httpClient: httpClient)
        self.jikanService = JikanService(httpClient: httpClient)
        self.iTunesService = ITunesCatalogService(httpClient: httpClient)
        self.internetArchiveService = InternetArchiveService(httpClient: httpClient)

        self.catalogRepository = CatalogRepository(
            tmdb: tmdbService,
            aniList: aniListService,
            tvMaze: tvMazeService,
            iTunes: iTunesService,
            cache: responseCache
        )
        self.detailsRepository = DetailsRepository(
            tmdb: tmdbService,
            aniList: aniListService,
            tvMaze: tvMazeService,
            jikan: jikanService,
            iTunes: iTunesService,
            cache: responseCache
        )
        self.calendarRepository = CalendarRepository(
            aniList: aniListService,
            tvMaze: tvMazeService,
            tmdb: tmdbService,
            cache: responseCache
        )

        let libRepo = LibraryRepository(modelContext: context)
        self.libraryRepository = libRepo
        let progRepo = ProgressRepository(modelContext: context, libraryRepository: libRepo)
        self.progressRepository = progRepo
        self.collectionsRepository = CollectionsRepository(modelContext: context)
        self.searchHistoryRepository = SearchHistoryRepository(modelContext: context)
        let settings = SettingsStore(modelContext: context)
        self.settingsStore = settings

        self.sourceManager = VideoSourceManager(
            modelContext: context,
            httpClient: httpClient,
            internetArchiveService: internetArchiveService,
            iTunesService: iTunesService
        )
        self.trackerService = TrackerService(
            libraryRepository: libRepo,
            progressRepository: progRepo
        )
        self.recommendationEngine = RecommendationEngine(
            catalogRepository: catalogRepository,
            libraryRepository: libRepo
        )
        self.alertScheduler = EpisodeAlertScheduler(
            libraryRepository: libRepo,
            detailsRepository: detailsRepository,
            settingsStore: settings
        )
        self.widgetWriter = WidgetSnapshotWriter(
            progressRepository: progRepo,
            calendarRepository: calendarRepository,
            libraryRepository: libRepo,
            settingsStore: settings
        )
    }

    public func performBackgroundMaintenance() async {
        await alertScheduler.syncScheduledAlerts()
        await widgetWriter.refreshWidgets()
    }
}
