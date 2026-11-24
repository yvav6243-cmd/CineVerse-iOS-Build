import SwiftUI

public struct LibraryView: View {
    let container: AppContainer

    @State private var viewModel: LibraryViewModel
    @State private var showNewCollectionSheet: Bool = false
    @State private var renamingCollection: CustomCollectionRecord?

    public init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: LibraryViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 0) {
            sectionChipsBar
                .padding(.vertical, CVSpacing.xs)
                .background(.bar)
            Divider()
            contentBody
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My List")
        .searchable(text: $viewModel.searchText, prompt: "Filter saved titles")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.selectedSection == .collections {
                    Button {
                        Haptics.impact(.light)
                        showNewCollectionSheet = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                } else {
                    filterAndSortMenus
                    Button {
                        Haptics.selection()
                        withAnimation(CVMotion.snappy) {
                            viewModel.isGridLayout.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.isGridLayout ? "list.bullet" : "square.grid.2x2")
                    }
                    .accessibilityLabel(viewModel.isGridLayout ? "Switch to List Layout" : "Switch to Grid Layout")
                }
            }
        }
        .sheet(isPresented: $showNewCollectionSheet) {
            CollectionEditorSheet { name, symbol in
                viewModel.createCollection(name: name, symbolName: symbol)
            }
        }
        .sheet(item: $renamingCollection) { collection in
            CollectionEditorSheet(existingCollection: collection) { name, symbol in
                viewModel.renameCollection(collection, name: name, symbolName: symbol)
            }
        }
        .onAppear { viewModel.reload() }
    }

    private var sectionChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CVSpacing.xs) {
                ForEach(LibrarySection.allCases) { section in
                    FilterChip(
                        title: NSLocalizedString(section.rawValue, comment: ""),
                        symbolName: section.symbolName,
                        isSelected: viewModel.selectedSection == section
                    ) {
                        withAnimation(CVMotion.snappy) {
                            viewModel.selectedSection = section
                        }
                    }
                }
            }
            .padding(.horizontal, CVSpacing.md)
        }
    }

    @ViewBuilder
    private var filterAndSortMenus: some View {
        Menu {
            Button {
                viewModel.selectedProjectType = nil
            } label: {
                if viewModel.selectedProjectType == nil {
                    Label("All Categories", systemImage: "checkmark")
                } else {
                    Text("All Categories")
                }
            }
            Divider()
            ForEach(MediaProjectType.allCases) { type in
                Button {
                    viewModel.selectedProjectType = type
                } label: {
                    Label(
                        type.pluralTitle,
                        systemImage: viewModel.selectedProjectType == type ? "checkmark" : type.symbolName
                    )
                }
            }
        } label: {
            Image(
                systemName: viewModel.selectedProjectType == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityLabel("Filter by Category")

        Menu {
            Picker("Sort By", selection: $viewModel.sortOption) {
                ForEach(LibrarySortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort Titles")
    }

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.selectedSection == .collections {
            collectionsView
        } else {
            let items = viewModel.filteredEntries
            if items.isEmpty {
                EmptyStateView(
                    title: "Nothing in \(viewModel.selectedSection.rawValue)",
                    message: emptyMessage(for: viewModel.selectedSection),
                    symbolName: viewModel.selectedSection.symbolName
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isGridLayout {
                gridLibraryView(items)
            } else {
                listLibraryView(items)
            }
        }
    }

    private func gridLibraryView(_ items: [LibraryEntryRecord]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 156, maximum: 180), spacing: CVSpacing.sm)],
                spacing: CVSpacing.md
            ) {
                ForEach(items, id: \.mediaID) { entry in
                    let card = PosterCard(
                        item: entry.resolvedMediaItem,
                        width: 160,
                        progressFraction: viewModel.progressByMediaID[entry.mediaID]
                    )
                    if let ref = entry.resolvedReference {
                        NavigationLink(value: Route.details(ref)) { card }
                            .buttonStyle(.plain)
                            .contextMenu { entryContextMenu(entry) }
                    } else {
                        card.contextMenu { entryContextMenu(entry) }
                    }
                }
            }
            .padding(CVSpacing.md)
        }
    }

    private func listLibraryView(_ items: [LibraryEntryRecord]) -> some View {
        List {
            ForEach(items, id: \.mediaID) { entry in
                listRow(entry)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { viewModel.deleteEntry(entry) } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        Button { viewModel.toggleWatchlist(entry) } label: {
                            Label(
                                entry.inWatchlist ? "Unbookmark" : "Watchlist",
                                systemImage: entry.inWatchlist ? "bookmark.slash" : "bookmark.fill"
                            )
                        }
                        .tint(CVColor.iris)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { viewModel.toggleFavorite(entry) } label: {
                            Label(
                                entry.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: entry.isFavorite ? "heart.slash.fill" : "heart.fill"
                            )
                        }
                        .tint(Color.pink)
                    }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func listRow(_ entry: LibraryEntryRecord) -> some View {
        let content = HStack(spacing: CVSpacing.sm) {
            CachedAsyncImage(
                url: entry.posterURL,
                targetSize: CGSize(width: 58, height: 87),
                fallbackSymbol: entry.projectType.symbolName
            )
            .frame(width: 48, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.projectType.displayName)
                    if entry.releaseYear > 0 {
                        Text("•")
                        Text(String(entry.releaseYear))
                    }
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if let status = entry.status {
                        StatusBadge(trackingStatus: status)
                    }
                    if entry.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color.pink)
                    }
                }
            }

            Spacer(minLength: 6)

            if let rating = entry.personalRating, rating > 0 {
                RatingBadge(score: rating, compact: true)
            }
        }
        .padding(.vertical, 4)

        if let ref = entry.resolvedReference {
            NavigationLink(value: Route.details(ref)) { content }
        } else {
            content
        }
    }

    @ViewBuilder
    private func entryContextMenu(_ entry: LibraryEntryRecord) -> some View {
        Button { viewModel.toggleFavorite(entry) } label: {
            Label(
                entry.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: entry.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button { viewModel.toggleWatchlist(entry) } label: {
            Label(
                entry.inWatchlist ? "Remove from Watchlist" : "Add to Watchlist",
                systemImage: entry.inWatchlist ? "bookmark.slash" : "bookmark"
            )
        }
        Menu("Set Status") {
            ForEach(WatchTrackingStatus.allCases) { status in
                Button { viewModel.setStatus(status, for: entry) } label: {
                    Label(status.rawValue, systemImage: status.symbolName)
                }
            }
        }
        Button(role: .destructive) { viewModel.deleteEntry(entry) } label: {
            Label("Remove from Library", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var collectionsView: some View {
        if viewModel.collections.isEmpty {
            EmptyStateView(
                title: "No Collections Yet",
                message: "Group movies, series, and anime into custom lists like \"Must Watch\" or \"Best Anime\".",
                symbolName: "rectangle.stack.badge.plus",
                actionTitle: "New Collection"
            ) {
                showNewCollectionSheet = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 162, maximum: 210), spacing: CVSpacing.md)],
                    spacing: CVSpacing.md
                ) {
                    ForEach(viewModel.collections, id: \.id) { collection in
                        NavigationLink(value: Route.collection(collection.id)) {
                            collectionCard(collection)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { renamingCollection = collection } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) { viewModel.deleteCollection(collection) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(CVSpacing.md)
            }
        }
    }

    private func collectionCard(_ collection: CustomCollectionRecord) -> some View {
        let previewItems = Array(collection.sortedItems.prefix(3))

        return VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    if let item = previewItems[safe: index] {
                        CachedAsyncImage(
                            url: item.posterURL,
                            targetSize: CGSize(width: 90, height: 135),
                            fallbackSymbol: item.projectType.symbolName
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                            .frame(maxWidth: .infinity)
                            .frame(height: 112)
                            .overlay {
                                if index == 0 && previewItems.isEmpty {
                                    Image(systemName: collection.symbolName)
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                }
            }
            .padding(6)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))

            HStack(spacing: 6) {
                Image(systemName: collection.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CVColor.iris)
                Text(collection.name)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text("\(collection.items.count) \(collection.items.count == 1 ? "title" : "titles")")
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
        }
        .padding(CVSpacing.xs)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private func emptyMessage(for section: LibrarySection) -> String {
        switch section {
        case .watchlist:
            return "Bookmark titles you plan to watch and they will appear here offline."
        case .favorites:
            return "Mark movies, anime, or shows as favorites to keep them close."
        default:
            return "Titles with status \"\(section.rawValue)\" will show up here automatically."
        }
    }
}
