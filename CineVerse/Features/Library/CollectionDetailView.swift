import SwiftUI

public struct CollectionDetailView: View {
    let collectionID: UUID
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @State private var collection: CustomCollectionRecord?
    @State private var sortMode: CollectionSortMode = .custom
    @State private var editMode: EditMode = .inactive
    @State private var showRenameSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    private enum CollectionSortMode: String, CaseIterable, Identifiable {
        case custom = "Custom Order"
        case title = "Title"
        case releaseYear = "Release Year"
        case rating = "Rating"
        case dateAdded = "Date Added"

        var id: String { rawValue }
    }

    public init(collectionID: UUID, container: AppContainer) {
        self.collectionID = collectionID
        self.container = container
    }

    private var displayedItems: [CollectionItemRecord] {
        guard let collection else { return [] }
        switch sortMode {
        case .custom:
            return collection.sortedItems
        case .title:
            return collection.sortedItems.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .releaseYear:
            return collection.sortedItems.sorted { $0.releaseYear > $1.releaseYear }
        case .rating:
            return collection.sortedItems.sorted { $0.rating > $1.rating }
        case .dateAdded:
            return collection.sortedItems.sorted { $0.addedAt > $1.addedAt }
        }
    }

    public var body: some View {
        Group {
            if let collection {
                if collection.items.isEmpty {
                    EmptyStateView(
                        title: "Collection is Empty",
                        message: "Add movies, series, or anime to \"\(collection.name)\" from any title's details screen.",
                        symbolName: collection.symbolName
                    )
                } else {
                    List {
                        ForEach(displayedItems, id: \.id) { item in
                            collectionItemRow(item)
                        }
                        .onMove(perform: sortMode == .custom ? moveItems : nil)
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, $editMode)
                }
            } else {
                EmptyStateView(
                    title: "Collection Not Found",
                    message: "This collection may have been deleted.",
                    symbolName: "folder.badge.questionmark"
                )
            }
        }
        .navigationTitle(collection?.name ?? "Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if collection != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !(collection?.items.isEmpty ?? true) {
                        Button(editMode.isEditing ? "Done" : "Reorder") {
                            withAnimation(CVMotion.snappy) {
                                if !editMode.isEditing {
                                    sortMode = .custom
                                    editMode = .active
                                } else {
                                    editMode = .inactive
                                }
                            }
                        }

                        Menu {
                            Picker("Sort By", selection: $sortMode) {
                                ForEach(CollectionSortMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .disabled(editMode.isEditing)
                    }

                    Menu {
                        Button {
                            showRenameSheet = true
                        } label: {
                            Label("Rename Collection", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let collection {
                CollectionEditorSheet(existingCollection: collection) { newName, newSymbol in
                    container.collectionsRepository.renameCollection(
                        id: collection.id,
                        name: newName,
                        symbolName: newSymbol
                    )
                    reload()
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(collection?.name ?? "Collection")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Collection", role: .destructive) {
                container.collectionsRepository.deleteCollection(id: collectionID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Titles in your library will remain safe; only this collection is removed.")
        }
        .onAppear {
            reload()
        }
    }

    @ViewBuilder
    private func collectionItemRow(_ item: CollectionItemRecord) -> some View {
        let content = HStack(spacing: CVSpacing.sm) {
            CachedAsyncImage(
                url: item.posterURL,
                targetSize: CGSize(width: 56, height: 84),
                fallbackSymbol: item.projectType.symbolName
            )
            .frame(width: 46, height: 69)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.projectType.displayName)
                    if item.releaseYear > 0 {
                        Text("•")
                        Text(String(item.releaseYear))
                    }
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            RatingBadge(score: item.rating, compact: true)
        }
        .padding(.vertical, 2)

        if let ref = MediaReference(id: item.mediaID) {
            NavigationLink(value: Route.details(ref)) {
                content
            }
        } else {
            content
        }
    }

    private func reload() {
        collection = container.collectionsRepository.collection(id: collectionID)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        container.collectionsRepository.reorderItems(
            in: collectionID,
            fromOffsets: source,
            toOffset: destination
        )
        reload()
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = displayedItems
        for index in offsets {
            guard let target = items[safe: index] else { continue }
            container.collectionsRepository.remove(mediaID: target.mediaID, from: collectionID)
        }
        reload()
    }
}
