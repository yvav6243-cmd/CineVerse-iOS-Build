import Foundation
import SwiftData

public enum CollectionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard = "Standard List"
    case thematic = "Thematic Collection"
    case genre = "Genre List"
    case mood = "Mood List"
    case watchLater = "Future Watch"
    case favorites = "Favorites Showcase"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .standard: return "list.bullet.rectangle.fill"
        case .thematic: return "sparkles.rectangle.stack.fill"
        case .genre: return "theatermasks.fill"
        case .mood: return "moon.stars.fill"
        case .watchLater: return "clock.badge.checkmark.fill"
        case .favorites: return "heart.rectangle.fill"
        }
    }
}

public enum WatchPriorityLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case mustWatch = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low: return "Low Priority"
        case .normal: return "Normal"
        case .high: return "High Priority"
        case .mustWatch: return "Must Watch"
        }
    }

    public var shortBadge: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .mustWatch: return "Must Watch"
        }
    }

    public var symbolName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .normal: return "minus.circle"
        case .high: return "exclamationmark.circle.fill"
        case .mustWatch: return "flame.fill"
        }
    }
}

@Model
public final class CustomCollectionRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var symbolName: String
    public var collectionDescription: String
    public var kindRaw: String
    public var customCoverURLString: String?
    public var createdAt: Date
    public var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \CollectionItemRecord.collection)
    public var items: [CollectionItemRecord]

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "folder.fill",
        collectionDescription: String = "",
        kind: CollectionKind = .standard,
        customCoverURLString: String? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        items: [CollectionItemRecord] = []
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.collectionDescription = collectionDescription
        self.kindRaw = kind.rawValue
        self.customCoverURLString = customCoverURLString
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.items = items
    }

    public var kind: CollectionKind {
        get { CollectionKind(rawValue: kindRaw) ?? .standard }
        set { kindRaw = newValue.rawValue }
    }

    public var customCoverURL: URL? {
        customCoverURLString?.nilIfEmpty.flatMap(URL.init(string:))
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
    public var priorityRaw: Int
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
        priority: WatchPriorityLevel = .normal,
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
        self.priorityRaw = priority.rawValue
        self.addedAt = addedAt
        self.position = position
        self.collection = collection
    }

    public var projectType: MediaProjectType {
        MediaProjectType(rawValue: projectTypeRaw) ?? .other
    }

    public var priority: WatchPriorityLevel {
        get { WatchPriorityLevel(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
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
