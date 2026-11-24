import Foundation

public struct MediaReference: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case movie
        case tv
        case anime
    }

    public let provider: MetadataProviderSource
    public let kind: Kind
    public let providerID: String

    public init(provider: MetadataProviderSource, kind: Kind, providerID: String) {
        self.provider = provider
        self.kind = kind
        self.providerID = providerID
    }

    public var id: String {
        "\(Self.prefix(for: provider)):\(kind.rawValue):\(providerID)"
    }

    public init?(id: String) {
        let parts = id.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3,
              let provider = Self.provider(for: parts[0]),
              let kind = Kind(rawValue: parts[1]),
              !parts[2].isEmpty else {
            return nil
        }
        self.provider = provider
        self.kind = kind
        self.providerID = parts[2]
    }

    public var shareURL: URL? {
        switch provider {
        case .tmdb:
            let segment = kind == .movie ? "movie" : "tv"
            return URL(string: "https://www.themoviedb.org/\(segment)/\(providerID)")
        case .aniList:
            return URL(string: "https://anilist.co/anime/\(providerID)")
        case .tvMaze:
            return URL(string: "https://www.tvmaze.com/shows/\(providerID)")
        case .openCinema:
            if providerID.hasPrefix("itunes-") {
                let idDigits = providerID.replacingOccurrences(of: "itunes-", with: "")
                return URL(string: "https://itunes.apple.com/us/movie/id\(idDigits)")
            }
            return nil
        }
    }

    private static func prefix(for provider: MetadataProviderSource) -> String {
        switch provider {
        case .tmdb: return "tmdb"
        case .aniList: return "anilist"
        case .tvMaze: return "tvmaze"
        case .openCinema: return "opencinema"
        }
    }

    private static func provider(for prefix: String) -> MetadataProviderSource? {
        switch prefix.lowercased() {
        case "tmdb": return .tmdb
        case "anilist": return .aniList
        case "tvmaze": return .tvMaze
        case "opencinema": return .openCinema
        default: return nil
        }
    }
}

public extension MediaItem {
    var reference: MediaReference? {
        if let parsed = MediaReference(id: id) {
            return parsed
        }
        let kind: MediaReference.Kind
        switch primarySource {
        case .aniList:
            kind = .anime
        case .tvMaze:
            kind = .tv
        case .tmdb, .openCinema:
            kind = projectType.isEpisodic ? .tv : .movie
        }
        let rawID = externalIDs[primarySource] ?? id
        return MediaReference(provider: primarySource, kind: kind, providerID: rawID)
    }
}
