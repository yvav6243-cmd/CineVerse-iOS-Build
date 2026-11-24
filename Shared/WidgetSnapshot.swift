import Foundation

public struct WidgetContinueItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let progressFraction: Double
    public let deepLinkURLString: String
    public let thumbnailFileName: String?

    public init(
        id: String,
        title: String,
        subtitle: String,
        progressFraction: Double,
        deepLinkURLString: String,
        thumbnailFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.progressFraction = progressFraction
        self.deepLinkURLString = deepLinkURLString
        self.thumbnailFileName = thumbnailFileName
    }
}

public struct WidgetUpcomingItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let episodeLabel: String
    public let airDate: Date
    public let deepLinkURLString: String

    public init(
        id: String,
        title: String,
        episodeLabel: String,
        airDate: Date,
        deepLinkURLString: String
    ) {
        self.id = id
        self.title = title
        self.episodeLabel = episodeLabel
        self.airDate = airDate
        self.deepLinkURLString = deepLinkURLString
    }
}

public struct WidgetSnapshot: Codable, Sendable {
    public let updatedAt: Date
    public let continueWatching: [WidgetContinueItem]
    public let upcoming: [WidgetUpcomingItem]

    public init(
        updatedAt: Date = Date(),
        continueWatching: [WidgetContinueItem] = [],
        upcoming: [WidgetUpcomingItem] = []
    ) {
        self.updatedAt = updatedAt
        self.continueWatching = continueWatching
        self.upcoming = upcoming
    }
}
