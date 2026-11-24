import Foundation

public struct TVMazeImageDTO: Decodable, Sendable {
    public let medium: String?
    public let original: String?
}

public struct TVMazeRatingDTO: Decodable, Sendable {
    public let average: Double?
}

public struct TVMazeCountryDTO: Decodable, Sendable {
    public let name: String?
    public let code: String?
}

public struct TVMazeNetworkDTO: Decodable, Sendable {
    public let id: Int?
    public let name: String?
    public let country: TVMazeCountryDTO?
    public let officialSite: String?
}

public struct TVMazeExternalsDTO: Decodable, Sendable {
    public let tvrage: Int?
    public let thetvdb: Int?
    public let imdb: String?
}

public struct TVMazeNextEpisodeRefDTO: Decodable, Sendable {
    public let href: String?
    public let name: String?
}

public struct TVMazeLinksDTO: Decodable, Sendable {
    public let nextepisode: TVMazeNextEpisodeRefDTO?
}

public struct TVMazePersonDTO: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let image: TVMazeImageDTO?
}

public struct TVMazeCharacterDTO: Decodable, Sendable {
    public let id: Int?
    public let name: String?
}

public struct TVMazeCastMemberDTO: Decodable, Sendable {
    public let person: TVMazePersonDTO
    public let character: TVMazeCharacterDTO?
}

public struct TVMazeSeasonDTO: Decodable, Sendable {
    public let id: Int
    public let number: Int
    public let name: String?
    public let episodeOrder: Int?
    public let premiereDate: String?
    public let endDate: String?
    public let image: TVMazeImageDTO?
    public let summary: String?
}

public struct TVMazeEpisodeDTO: Decodable, Sendable {
    public let id: Int
    public let name: String?
    public let season: Int?
    public let number: Int?
    public let airdate: String?
    public let airstamp: String?
    public let runtime: Int?
    public let image: TVMazeImageDTO?
    public let summary: String?
}

public struct TVMazeEmbeddedDTO: Decodable, Sendable {
    public let cast: [TVMazeCastMemberDTO]?
    public let seasons: [TVMazeSeasonDTO]?
    public let episodes: [TVMazeEpisodeDTO]?
    public let show: TVMazeShowDTO?
}

public struct TVMazeShowDTO: Decodable, Sendable {
    public let id: Int
    public let url: String?
    public let name: String
    public let type: String?
    public let language: String?
    public let genres: [String]?
    public let status: String?
    public let runtime: Int?
    public let averageRuntime: Int?
    public let premiered: String?
    public let ended: String?
    public let officialSite: String?
    public let weight: Int?
    public let network: TVMazeNetworkDTO?
    public let webChannel: TVMazeNetworkDTO?
    public let externals: TVMazeExternalsDTO?
    public let image: TVMazeImageDTO?
    public let summary: String?
    public let links: TVMazeLinksDTO?
    public let embedded: TVMazeEmbeddedDTO?

    enum CodingKeys: String, CodingKey {
        case id, url, name, type, language, genres, status, runtime, averageRuntime
        case premiered, ended, officialSite, weight, network, webChannel, externals, image, summary
        case links = "_links"
        case embedded = "_embedded"
    }
}

public struct TVMazeSearchResultDTO: Decodable, Sendable {
    public let score: Double
    public let show: TVMazeShowDTO
}

public struct TVMazeScheduleEntryDTO: Decodable, Sendable {
    public let id: Int
    public let name: String?
    public let season: Int?
    public let number: Int?
    public let airdate: String?
    public let airstamp: String?
    public let show: TVMazeShowDTO?
    public let embedded: TVMazeEmbeddedDTO?

    enum CodingKeys: String, CodingKey {
        case id, name, season, number, airdate, airstamp, show
        case embedded = "_embedded"
    }
}
