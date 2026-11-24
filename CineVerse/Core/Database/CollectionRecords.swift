import Foundation
import SwiftData

@Model
public final class CustomCollectionRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var symbolName: String
    public var createdAt: Date
    public var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \CollectionItemRecord.collection)
    public var items: [CollectionItemRecord]

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "folder.fill",
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        items: [CollectionItemRecord] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.items = items
    }

    public var sortedItems: [CollectionItemRecord] {
        items.sorted { $0.position < $1.position }
    }

    public func toDTO() -> CollectionDTO {
        CollectionDTO(
            id: id,
            name: name,
            symbolName: symbolName,
            createdAt: createdAt,
            sortOrder: sortOrder,
            items: sortedItems.map { $0.toDTO() }
        )
    }
}

@Model
public final class CollectionItemRecord {
    public var id: UUID
    public var mediaID: String
    public var title: String
    public var posterURLString: String?
    public var projectTypeRaw: String
    public var releaseYear: Int
    public var rating: Double
    public var addedAt: Date
    public var position: Int
    public var collection: CustomCollectionRecord?

    public init(
        id: UUID = UUID(),
        mediaID: String,
        title: String,
        posterURLString: String? = nil,
        projectTypeRaw: String,
        releaseYear: Int,
        rating: Double,
        addedAt: Date = Date(),
        position: Int = 0,
        collection: CustomCollectionRecord? = nil
    ) {
        self.id = id
        self.mediaID = mediaID
        self.title = title
        self.posterURLString = posterURLString
        self.projectTypeRaw = projectTypeRaw
        self.releaseYear = releaseYear
        self.rating = rating
        self.addedAt = addedAt
        self.position = position
        self.collection = collection
    }

    public var projectType: MediaProjectType {
        MediaProjectType(rawValue: projectTypeRaw) ?? .other
    }

    public var posterURL: URL? {
        posterURLString.flatMap(URL.init(string:))
    }

    public func toDTO() -> CollectionItemDTO {
        CollectionItemDTO(
            mediaID: mediaID,
            title: title,
            posterURLString: posterURLString,
            projectTypeRaw: projectTypeRaw,
            releaseYear: releaseYear,
            rating: rating,
            addedAt: addedAt,
            position: position
        )
    }
}
