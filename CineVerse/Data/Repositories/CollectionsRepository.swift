import Foundation
import SwiftData

@MainActor
public protocol CollectionsRepositoryProtocol: AnyObject {
    func allCollections() -> [CustomCollectionRecord]
    func collection(id: UUID) -> CustomCollectionRecord?
    @discardableResult
    func createCollection(name: String, symbolName: String) -> CustomCollectionRecord
    @discardableResult
    func createSmartCollection(
        name: String,
        symbolName: String,
        description: String,
        kind: CollectionKind,
        coverURLString: String?
    ) -> CustomCollectionRecord
    func renameCollection(id: UUID, name: String, symbolName: String)
    func updateCollectionDetails(
        id: UUID,
        name: String,
        symbolName: String,
        description: String,
        kind: CollectionKind,
        coverURLString: String?
    )
    func setItemPriority(in collectionID: UUID, mediaID: String, priority: WatchPriorityLevel)
    func deleteCollection(id: UUID)
    func add(item: MediaItem, to collectionID: UUID)
    func remove(mediaID: String, from collectionID: UUID)
    func reorderItems(in collectionID: UUID, fromOffsets: IndexSet, toOffset: Int)
    func collectionIDs(containing mediaID: String) -> Set<UUID>
}

@MainActor
public final class CollectionsRepository: CollectionsRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func allCollections() -> [CustomCollectionRecord] {
        let descriptor = FetchDescriptor<CustomCollectionRecord>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func collection(id: UUID) -> CustomCollectionRecord? {
        let descriptor = FetchDescriptor<CustomCollectionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func createCollection(name: String, symbolName: String) -> CustomCollectionRecord {
        createSmartCollection(name: name, symbolName: symbolName, description: "", kind: .standard, coverURLString: nil)
    }

    @discardableResult
    public func createSmartCollection(
        name: String,
        symbolName: String,
        description: String,
        kind: CollectionKind,
        coverURLString: String?
    ) -> CustomCollectionRecord {
        let nextOrder = (allCollections().map(\.sortOrder).max() ?? -1) + 1
        let collection = CustomCollectionRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            collectionDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            customCoverURLString: coverURLString?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sortOrder: nextOrder
        )
        modelContext.insert(collection)
        save()
        return collection
    }

    public func renameCollection(id: UUID, name: String, symbolName: String) {
        guard let target = collection(id: id) else { return }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.symbolName = symbolName
        save()
    }

    public func updateCollectionDetails(
        id: UUID,
        name: String,
        symbolName: String,
        description: String,
        kind: CollectionKind,
        coverURLString: String?
    ) {
        guard let target = collection(id: id) else { return }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.symbolName = symbolName
        target.collectionDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        target.kind = kind
        target.customCoverURLString = coverURLString?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        save()
    }

    public func setItemPriority(in collectionID: UUID, mediaID: String, priority: WatchPriorityLevel) {
        guard let target = collection(id: collectionID) else { return }
        for item in target.items where item.mediaID == mediaID {
            item.priority = priority
        }
        save()
    }

    public func deleteCollection(id: UUID) {
        guard let target = collection(id: id) else { return }
        modelContext.delete(target)
        save()
    }

    public func add(item: MediaItem, to collectionID: UUID) {
        guard let target = collection(id: collectionID) else { return }
        guard !target.items.contains(where: { $0.mediaID == item.id }) else { return }

        let nextPosition = (target.items.map(\.position).max() ?? -1) + 1
        let record = CollectionItemRecord(
            mediaID: item.id,
            title: item.localizedTitle,
            posterURLString: item.posterURL?.absoluteString,
            projectTypeRaw: item.projectType.rawValue,
            releaseYear: item.releaseYear,
            rating: item.displayRating,
            position: nextPosition,
            collection: target
        )
        modelContext.insert(record)
        target.items.append(record)
        save()
    }

    public func remove(mediaID: String, from collectionID: UUID) {
        guard let target = collection(id: collectionID) else { return }
        let matching = target.items.filter { $0.mediaID == mediaID }
        for item in matching {
            target.items.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }
        reindex(target)
        save()
    }

    public func reorderItems(in collectionID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let target = collection(id: collectionID) else { return }
        var ordered = target.sortedItems
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
        save()
    }

    public func collectionIDs(containing mediaID: String) -> Set<UUID> {
        let collections = allCollections()
        return Set(
            collections
                .filter { $0.items.contains(where: { $0.mediaID == mediaID }) }
                .map(\.id)
        )
    }

    private func reindex(_ collection: CustomCollectionRecord) {
        let ordered = collection.sortedItems
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            CVLogger.database.error("Collections save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
