import Foundation
import SwiftData

public enum UserVideoSourceKind: String, Codable, Sendable {
    case localFile
    case directLink
}

@Model
public final class UserVideoSourceRecord {
    @Attribute(.unique) public var id: UUID
    public var mediaID: String
    public var season: Int?
    public var episode: Int?
    public var kindRaw: String
    public var urlString: String?
    public var relativeFilePath: String?
    public var label: String
    public var subtitleFilesData: Data
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        mediaID: String,
        season: Int? = nil,
        episode: Int? = nil,
        kind: UserVideoSourceKind,
        urlString: String? = nil,
        relativeFilePath: String? = nil,
        label: String,
        subtitles: [StoredSubtitleDTO] = [],
        addedAt: Date = Date()
    ) {
        self.id = id
        self.mediaID = mediaID
        self.season = season
        self.episode = episode
        self.kindRaw = kind.rawValue
        self.urlString = urlString
        self.relativeFilePath = relativeFilePath
        self.label = label
        self.subtitleFilesData = (try? JSONEncoder().encode(subtitles)) ?? Data()
        self.addedAt = addedAt
    }

    public var kind: UserVideoSourceKind {
        get { UserVideoSourceKind(rawValue: kindRaw) ?? .directLink }
        set { kindRaw = newValue.rawValue }
    }

    public var subtitles: [StoredSubtitleDTO] {
        get {
            (try? JSONDecoder().decode([StoredSubtitleDTO].self, from: subtitleFilesData)) ?? []
        }
        set {
            subtitleFilesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public func toDTO() -> UserVideoSourceDTO {
        UserVideoSourceDTO(
            id: id,
            mediaID: mediaID,
            season: season,
            episode: episode,
            kindRaw: kindRaw,
            urlString: kind == .directLink ? urlString : relativeFilePath,
            label: label,
            isRestorable: kind == .directLink,
            subtitles: subtitles,
            addedAt: addedAt
        )
    }
}
