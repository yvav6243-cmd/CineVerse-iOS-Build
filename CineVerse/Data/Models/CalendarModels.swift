import Foundation

public struct PremiereEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let mediaReference: MediaReference
    public let title: String
    public let episodeTitle: String?
    public let posterURL: URL?
    public let date: Date
    public let episodeNumber: Int?
    public let seasonNumber: Int?
    public let kind: MediaProjectType
    public let source: MetadataProviderSource

    public init(
        id: String,
        mediaReference: MediaReference,
        title: String,
        episodeTitle: String? = nil,
        posterURL: URL? = nil,
        date: Date,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil,
        kind: MediaProjectType,
        source: MetadataProviderSource
    ) {
        self.id = id
        self.mediaReference = mediaReference
        self.title = title
        self.episodeTitle = episodeTitle
        self.posterURL = posterURL
        self.date = date
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.kind = kind
        self.source = source
    }

    public var formattedEpisodeLabel: String? {
        guard let ep = episodeNumber else { return nil }
        if let season = seasonNumber {
            return String(format: "S%d E%d", season, ep)
        }
        return "Episode \(ep)"
    }
}

public struct DailyWatchActivityPoint: Identifiable, Hashable, Sendable {
    public let id: String
    public let date: Date
    public let dayLabel: String
    public let minutesWatched: Int

    public init(date: Date, dayLabel: String, minutesWatched: Int) {
        self.id = CineVerseDateFormatters.isoDateParser.string(from: date)
        self.date = date
        self.dayLabel = dayLabel
        self.minutesWatched = minutesWatched
    }
}
