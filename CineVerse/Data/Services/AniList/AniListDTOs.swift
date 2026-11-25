import Foundation

public struct AniListGraphQLResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T?
}

public struct AniListPageDataDTO: Decodable, Sendable {
    public let page: AniListPageDTO

    enum CodingKeys: String, CodingKey {
        case page = "Page"
    }
}

public struct AniListMediaDataDTO: Decodable, Sendable {
    public let media: AniListMediaDTO?

    enum CodingKeys: String, CodingKey {
        case media = "Media"
    }
}

public struct AniListGenresDataDTO: Decodable, Sendable {
    public let genreCollection: [String]?

    enum CodingKeys: String, CodingKey {
        case genreCollection = "GenreCollection"
    }
}

public struct AniListPageDTO: Decodable, Sendable {
    public let pageInfo: AniListPageInfoDTO?
    public let media: [AniListMediaDTO]?
    public let airingSchedules: [AniListAiringScheduleDTO]?
}

public struct AniListPageInfoDTO: Decodable, Sendable {
    public let hasNextPage: Bool?
}

public struct AniListAiringScheduleDTO: Decodable, Sendable {
    public let airingAt: Int
    public let episode: Int
    public let media: AniListMediaDTO?
}

public struct AniListTitleDTO: Decodable, Sendable {
    public let romaji: String?
    public let english: String?
    public let native: String?
}

public struct AniListDateDTO: Decodable, Sendable {
    public let year: Int?
    public let month: Int?
    public let day: Int?
}

public struct AniListCoverImageDTO: Decodable, Sendable {
    public let extraLarge: String?
    public let color: String?
}

public struct AniListTrailerDTO: Decodable, Sendable {
    public let id: String?
    public let site: String?
    public let thumbnail: String?
}

public struct AniListNextAiringDTO: Decodable, Sendable {
    public let airingAt: Int
    public let episode: Int
}

public struct AniListStudioConnectionDTO: Decodable, Sendable {
    public let nodes: [AniListNameNodeDTO]?
}

public struct AniListNameNodeDTO: Decodable, Sendable {
    public let name: String?
}

public struct AniListStaffConnectionDTO: Decodable, Sendable {
    public let edges: [AniListStaffEdgeDTO]?
}

public struct AniListStaffEdgeDTO: Decodable, Sendable {
    public let role: String?
    public let node: AniListPersonNodeDTO?
}

public struct AniListCharacterConnectionDTO: Decodable, Sendable {
    public let edges: [AniListCharacterEdgeDTO]?
}

public struct AniListCharacterEdgeDTO: Decodable, Sendable {
    public let role: String?
    public let node: AniListPersonNodeDTO?
    public let voiceActors: [AniListVoiceActorDTO]?
}

public struct AniListVoiceActorDTO: Decodable, Sendable {
    public let name: AniListPersonNameDTO?
}

public struct AniListPersonNodeDTO: Decodable, Sendable {
    public let id: Int?
    public let name: AniListPersonNameDTO?
    public let image: AniListPersonImageDTO?
}

public struct AniListPersonNameDTO: Decodable, Sendable {
    public let full: String?
}

public struct AniListPersonImageDTO: Decodable, Sendable {
    public let medium: String?
}

public struct AniListRecommendationConnectionDTO: Decodable, Sendable {
    public let nodes: [AniListRecommendationNodeDTO]?
}

public struct AniListRecommendationNodeDTO: Decodable, Sendable {
    public let mediaRecommendation: AniListMediaDTO?
}

public struct AniListStreamingEpisodeDTO: Decodable, Sendable {
    public let title: String?
    public let thumbnail: String?
    public let url: String?
    public let site: String?
}

public struct AniListExternalLinkDTO: Decodable, Sendable {
    public let site: String?
    public let url: String?
    public let type: String?
    public let language: String?
}

public struct AniListMediaDTO: Decodable, Sendable {
    public let id: Int
    public let idMal: Int?
    public let title: AniListTitleDTO?
    public let synonyms: [String]?
    public let description: String?
    public let format: String?
    public let status: String?
    public let episodes: Int?
    public let duration: Int?
    public let seasonYear: Int?
    public let startDate: AniListDateDTO?
    public let countryOfOrigin: String?
    public let genres: [String]?
    public let averageScore: Int?
    public let popularity: Int?
    public let coverImage: AniListCoverImageDTO?
    public let bannerImage: String?
    public let isAdult: Bool?
    public let trailer: AniListTrailerDTO?
    public let nextAiringEpisode: AniListNextAiringDTO?
    public let studios: AniListStudioConnectionDTO?
    public let staff: AniListStaffConnectionDTO?
    public let characters: AniListCharacterConnectionDTO?
    public let recommendations: AniListRecommendationConnectionDTO?
    public let streamingEpisodes: [AniListStreamingEpisodeDTO]?
    public let externalLinks: [AniListExternalLinkDTO]?
}

public struct AniListEntitySearchDataDTO: Decodable, Sendable {
    public let studios: AniListEntityPageDTO?
    public let characters: AniListEntityPageDTO?
    public let staff: AniListEntityPageDTO?
}

public struct AniListEntityPageDTO: Decodable, Sendable {
    public let studios: [AniListStudioEntityDTO]?
    public let characters: [AniListCharacterEntityDTO]?
    public let staff: [AniListStaffEntityDTO]?
}

public struct AniListStudioEntityDTO: Decodable, Sendable {
    public let name: String?
    public let media: AniListMediaNodesContainerDTO?
}

public struct AniListCharacterEntityDTO: Decodable, Sendable {
    public let name: AniListPersonNameDTO?
    public let media: AniListMediaNodesContainerDTO?
}

public struct AniListStaffEntityDTO: Decodable, Sendable {
    public let name: AniListPersonNameDTO?
    public let staffMedia: AniListMediaNodesContainerDTO?
}

public struct AniListMediaNodesContainerDTO: Decodable, Sendable {
    public let nodes: [AniListMediaDTO]?
}
