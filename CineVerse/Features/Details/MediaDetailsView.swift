import SwiftUI
import UniformTypeIdentifiers

private struct AddSourceContext: Identifiable {
    let id = UUID()
    let item: MediaItem
    let episode: MediaEpisode?
    let initialTab: AddSourceTab
}

public struct MediaDetailsView: View {
    private let reference: MediaReference
    private let container: AppContainer
    private let transitionNamespace: Namespace.ID?

    @State private var viewModel: MediaDetailsViewModel
    @State private var playbackSetupVM: PlaybackSetupViewModel

    @State private var showAddToListSheet: Bool = false
    @State private var showNotesSheet: Bool = false
    @State private var addSourceContext: AddSourceContext?
    @State private var inAppSafariItem: InAppSafariSheetItem?
    @State private var embeddedTrailer: EmbeddedTrailerItem?
    @State private var showSubtitleImporter: Bool = false

    private var inAppWebURLBinding: Binding<URL?> {
        Binding(
            get: { inAppSafariItem?.url },
            set: { newURL in inAppSafariItem = newURL.map(InAppSafariSheetItem.init) }
        )
    }

    private func trailerURLBinding(for item: MediaItem) -> Binding<URL?> {
        Binding(
            get: { inAppSafariItem?.url },
            set: { newURL in
                guard let newURL else {
                    inAppSafariItem = nil
                    return
                }
                handleTrailerURL(newURL, for: item, allowSafariFallback: true)
            }
        )
    }

    public init(
        reference: MediaReference,
        container: AppContainer,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.reference = reference
        self.container = container
        self.transitionNamespace = transitionNamespace

        _viewModel = State(initialValue: MediaDetailsViewModel(
            reference: reference,
            detailsRepository: container.detailsRepository,
            libraryRepository: container.libraryRepository,
            progressRepository: container.progressRepository,
            collectionsRepository: container.collectionsRepository,
            trackerService: container.trackerService,
            settingsStore: container.settingsStore,
            networkMonitor: container.networkMonitor,
            widgetWriter: container.widgetWriter
        ))

        _playbackSetupVM = State(initialValue: PlaybackSetupViewModel(
            sourceManager: container.sourceManager,
            libraryRepository: container.libraryRepository,
            settingsStore: container.settingsStore
        ))
    }

    public var body: some View {
        ZStack {
            AmbientBackground(
                artworkURL: viewModel.item?.backdropURL ?? viewModel.item?.posterURL,
                palette: viewModel.palette
            )
            contentBody
        }
        .navigationTitle(viewModel.item?.localizedTitle ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item = viewModel.item {
                ToolbarItem(placement: .topBarTrailing) { toolbarMenu(for: item) }
            }
        }
        .task(id: reference.id) {
            await viewModel.load()
            if let item = viewModel.item {
                await playbackSetupVM.loadSources(for: item, episode: viewModel.primaryWatchCTA.targetEpisode)
            }
        }
        .onChange(of: container.coordinator.playerSelection) { _, newSelection in
            if newSelection == nil {
                viewModel.refreshLocalState()
                if let item = viewModel.item {
                    Task {
                        await playbackSetupVM.loadSources(for: item, episode: viewModel.primaryWatchCTA.targetEpisode)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddToListSheet) {
            if let item = viewModel.item {
                AddToListSheet(
                    item: item,
                    entry: viewModel.libraryEntry,
                    collections: viewModel.collections,
                    memberCollectionIDs: viewModel.memberCollectionIDs,
                    onToggleWatchlist: { viewModel.toggleWatchlist() },
                    onToggleFavorite: { viewModel.toggleFavorite() },
                    onSelectStatus: { viewModel.setStatus($0) },
                    onSetPersonalRating: { viewModel.setPersonalRating($0) },
                    onSetAlertsEnabled: { viewModel.setAlertsEnabled($0) },
                    onToggleCollection: { viewModel.toggleCollectionMembership(collectionID: $0) },
                    onCreateCollection: { viewModel.createCollection(name: $0, symbolName: $1) }
                )
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            if let item = viewModel.item {
                NotesEditorSheet(mediaTitle: item.localizedTitle, initialNotes: viewModel.libraryEntry?.notes ?? "") {
                    viewModel.setNotes($0)
                }
            }
        }
        .sheet(item: $addSourceContext) { ctx in
            AddSourceSheet(
                mediaItem: ctx.item,
                episode: ctx.episode,
                sourceManager: container.sourceManager,
                httpClient: container.httpClient,
                initialTab: ctx.initialTab
            ) {
                Task { await playbackSetupVM.loadSources(for: ctx.item, episode: ctx.episode) }
            }
        }
        .fileImporter(
            isPresented: $showSubtitleImporter,
            allowedContentTypes: subtitleContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await playbackSetupVM.importSubtitle(url: url) }
            }
        }
        .sheet(item: $inAppSafariItem) { safariItem in
            InAppSafariView(url: safariItem.url)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $embeddedTrailer) { trailerItem in
            EmbeddedTrailerPlayerView(item: trailerItem)
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch viewModel.state {
        case .idle, .loading:
            if let item = viewModel.item { loadedScrollView(item: item) }
            else { loadingSkeleton }
        case .failed(let message):
            if let item = viewModel.item { loadedScrollView(item: item) }
            else {
                ErrorStateView(message: message) {
                    Task { await viewModel.load(forceReload: true) }
                }
            }
        case .loaded(let item):
            loadedScrollView(item: item)
        }
    }

    private func loadedScrollView(item: MediaItem) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: CVSpacing.lg) {
                    DetailsHeaderView(item: item, transitionID: "\(item.id):header", transitionNamespace: transitionNamespace)
                    actionBar(for: item, scrollProxy: scrollProxy)
                    RatingComparisonView(ratings: item.ratings, personalRating: viewModel.libraryEntry?.personalRating) {
                        viewModel.setPersonalRating($0)
                    }
                    setupPanel(for: item)
                    synopsisSection(item: item)
                    TrailerCard(trailerURL: item.trailerURL, backdropURL: item.backdropURL ?? item.posterURL, title: item.localizedTitle, pendingExternalURL: trailerURLBinding(for: item))
                    episodesBlock(for: item, scrollProxy: scrollProxy)
                    CastRailView(cast: item.cast)
                    OfficialServicesSection(links: item.officialPlatformLinks, pendingExternalURL: inAppWebURLBinding)
                    personalNotesCard
                    similarProjectsSection
                }
                .padding(.bottom, CVSpacing.xxl)
            }
            .coordinateSpace(name: "detailsScroll")
        }
    }

    private func actionBar(for item: MediaItem, scrollProxy: ScrollViewProxy) -> some View {
        let cta = viewModel.primaryWatchCTA
        return DetailsActionBar(
            primaryCTATitle: cta.title,
            hasPlayableSource: playbackSetupVM.hasPlayableSource || item.trailerURL != nil,
            trackingStatus: viewModel.libraryEntry?.status,
            inWatchlist: viewModel.libraryEntry?.inWatchlist ?? false,
            isFavorite: viewModel.libraryEntry?.isFavorite ?? false,
            isAllWatched: viewModel.isAllWatched,
            shareURL: viewModel.shareURL ?? reference.shareURL,
            shareTitle: item.localizedTitle,
            onPrimaryWatch: {
                launchOrPromptAddSource(item: item, episode: cta.targetEpisode, startPosition: cta.startPositionSeconds, scrollProxy: scrollProxy)
            },
            onAddToList: { showAddToListSheet = true },
            onMarkWatched: { viewModel.markAllWatched() },
            onToggleFavorite: { viewModel.toggleFavorite() }
        )
    }

    private func setupPanel(for item: MediaItem) -> some View {
        PlaybackSetupPanel(
            item: item,
            viewModel: playbackSetupVM,
            startPositionSeconds: startPositionForSetup(item: item),
            onSelectEpisode: { ep in Task { await playbackSetupVM.selectEpisode(ep) } },
            onStartWatching: { container.coordinator.presentPlayer($0) },
            onOpenAddSource: { tab in
                addSourceContext = AddSourceContext(item: item, episode: playbackSetupVM.selectedEpisode, initialTab: tab)
            },
            onImportSubtitle: { showSubtitleImporter = true },
            onOpenOfficialURL: { inAppSafariItem = InAppSafariSheetItem(url: $0) },
            onPlayTrailer: {
                if let trailerURL = item.trailerURL {
                    handleTrailerURL(trailerURL, for: item, allowSafariFallback: false)
                }
            }
        )
        .id("playbackSetup")
    }

    @ViewBuilder
    private func episodesBlock(for item: MediaItem, scrollProxy: ScrollViewProxy) -> some View {
        if item.projectType.isEpisodic {
            EpisodesSection(
                item: item,
                selectedSeasonNumber: viewModel.selectedSeasonNumber,
                isLoadingSeason: viewModel.isLoadingSeason,
                seasonLoadError: viewModel.seasonLoadError,
                progressForEpisode: { viewModel.progress(for: $0) },
                onSelectSeason: { seasonNum in
                    Task {
                        await viewModel.selectSeason(seasonNum)
                        await syncDefaultEpisodeIfNeeded()
                    }
                },
                onRetrySeason: {
                    Task {
                        await viewModel.loadEpisodesForSeasonIfNeeded(seasonNumber: viewModel.selectedSeasonNumber)
                        await syncDefaultEpisodeIfNeeded()
                    }
                },
                onToggleWatched: { viewModel.toggleEpisodeWatched($0) },
                onPlayEpisode: { ep in
                    launchOrPromptAddSource(item: item, episode: ep, startPosition: resumePosition(for: ep), scrollProxy: scrollProxy)
                }
            )
        }
    }

    private func synopsisSection(item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(title: "Synopsis", symbolName: "text.alignleft", actionTitle: nil)
            ExpandableText(text: item.synopsis, lineLimit: 4)
                .padding(CVSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
                .padding(.horizontal, CVSpacing.md)
        }
    }

    private var personalNotesCard: some View {
        let notes = viewModel.libraryEntry?.notes ?? ""
        return VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(title: "Personal Notes", symbolName: "note.text", actionTitle: notes.isEmpty ? "Add" : "Edit") {
                showNotesSheet = true
            }

            Button {
                Haptics.selection()
                showNotesSheet = true
            } label: {
                HStack(alignment: .top, spacing: CVSpacing.sm) {
                    Image(systemName: notes.isEmpty ? "square.and.pencil" : "quote.opening")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CVColor.iris)

                    Text(notes.isEmpty ? "Add private notes, episode thoughts, or rewatch reminders..." : notes)
                        .font(notes.isEmpty ? CVFont.callout : CVFont.body)
                        .foregroundStyle(notes.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)

                    Spacer(minLength: 4)
                }
                .padding(CVSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CVSpacing.md)
        }
    }

    @ViewBuilder
    private var similarProjectsSection: some View {
        if viewModel.isLoadingSimilar {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                SectionHeader(title: "Similar Projects", symbolName: "sparkles", actionTitle: nil)
                ShimmerRail()
            }
        } else if !viewModel.similarItems.isEmpty {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                SectionHeader(title: "Similar Projects", symbolName: "sparkles", actionTitle: nil)
                MediaRail(items: viewModel.similarItems) { similar in
                    Button {
                        Haptics.selection()
                        if let ref = similar.reference { container.coordinator.navigate(to: .details(ref)) }
                    } label: {
                        PosterCard(
                            item: similar,
                            transitionNamespace: transitionNamespace,
                            transitionID: similar.reference?.id ?? similar.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingSkeleton: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CVSpacing.lg) {
                ShimmerHeroCard()
                ShimmerRail(cardWidth: 120, count: 3)
            }
            .padding(.top, CVSpacing.md)
        }
    }

    private func toolbarMenu(for item: MediaItem) -> some View {
        Menu {
            Button { showAddToListSheet = true } label: {
                Label("Manage in Library", systemImage: "rectangle.stack.badge.plus")
            }
            Button { showNotesSheet = true } label: {
                Label("Edit Personal Notes", systemImage: "note.text")
            }
            Button {
                addSourceContext = AddSourceContext(item: item, episode: playbackSetupVM.selectedEpisode, initialTab: .link)
            } label: {
                Label("Add Video Link / File", systemImage: "plus.circle")
            }
            Divider()
            Button { viewModel.markAllWatched() } label: {
                Label("Mark All as Watched", systemImage: "checkmark.seal.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.body.weight(.semibold))
        }
    }

    private func launchOrPromptAddSource(
        item: MediaItem,
        episode: MediaEpisode?,
        startPosition: TimeInterval,
        scrollProxy: ScrollViewProxy
    ) {
        Task {
            if playbackSetupVM.mediaItem?.id != item.id || episode?.id != playbackSetupVM.selectedEpisode?.id {
                await playbackSetupVM.loadSources(for: item, episode: episode)
            }
            var attempts = 0
            while (playbackSetupVM.isResolving || (playbackSetupVM.isInspecting && playbackSetupVM.selectedSource == nil)) && attempts < 35 {
                attempts += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let selection = playbackSetupVM.buildPlaybackSelection(startPositionSeconds: startPosition) {
                container.coordinator.presentPlayer(selection)
            } else if let trailerURL = item.trailerURL, isDirectVideoURL(trailerURL) {
                await playDirectTrailer(url: trailerURL, item: item)
            } else if let trailerURL = item.trailerURL, let videoID = EmbeddedTrailerItem.youTubeID(from: trailerURL) {
                embeddedTrailer = EmbeddedTrailerItem(videoID: videoID, title: item.localizedTitle)
            } else {
                withAnimation(CVMotion.spring) { scrollProxy.scrollTo("playbackSetup", anchor: .top) }
            }
        }
    }

    private func handleTrailerURL(_ url: URL, for item: MediaItem, allowSafariFallback: Bool) {
        if isDirectVideoURL(url) {
            Task { await playDirectTrailer(url: url, item: item) }
        } else if let videoID = EmbeddedTrailerItem.youTubeID(from: url) {
            embeddedTrailer = EmbeddedTrailerItem(videoID: videoID, title: item.localizedTitle)
        } else if allowSafariFallback {
            inAppSafariItem = InAppSafariSheetItem(url: url)
        }
    }

    private func isDirectVideoURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["m4v", "mp4", "mov", "m3u8"].contains(ext) {
            return true
        }
        return url.absoluteString.lowercased().contains(".m3u8")
    }

    private func playDirectTrailer(url: URL, item: MediaItem) async {
        let selection = await playbackSetupVM.buildDirectTrailerSelection(url: url, for: item)
        container.coordinator.presentPlayer(selection)
    }

    private func syncDefaultEpisodeIfNeeded() async {
        guard playbackSetupVM.selectedEpisode == nil, let updatedItem = viewModel.item else { return }
        await playbackSetupVM.loadSources(for: updatedItem, episode: viewModel.primaryWatchCTA.targetEpisode)
    }

    private func resumePosition(for episode: MediaEpisode) -> TimeInterval {
        guard let prog = viewModel.progress(for: episode),
              !prog.isWatched, prog.positionSeconds > 5, prog.fraction < 0.92 else { return 0 }
        return prog.positionSeconds
    }

    private func startPositionForSetup(item: MediaItem) -> TimeInterval {
        if item.projectType.isEpisodic {
            guard let ep = playbackSetupVM.selectedEpisode else { return 0 }
            return resumePosition(for: ep)
        }
        guard let prog = viewModel.movieProgress,
              !prog.isWatched, prog.positionSeconds > 5, prog.fraction < 0.92 else { return 0 }
        return prog.positionSeconds
    }

    private var subtitleContentTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let srt = UTType(filenameExtension: "srt") { types.append(srt) }
        if let vtt = UTType(filenameExtension: "vtt") { types.append(vtt) }
        return types
    }
}
