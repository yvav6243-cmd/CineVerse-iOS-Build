import Foundation

// MARK: - Apple iTunes RSS Feed DTOs

public struct ITunesRSSRootDTO: Decodable, Sendable {
    public let feed: ITunesRSSFeedDTO?
}

public struct ITunesRSSFeedDTO: Decodable, Sendable {
    public let entry: [ITunesRSSEntryDTO]?

    enum CodingKeys: String, CodingKey {
        case entry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let array = try? container.decode([ITunesRSSEntryDTO].self, forKey: .entry) {
            self.entry = array
        } else if let single = try? container.decode(ITunesRSSEntryDTO.self, forKey: .entry) {
            self.entry = [single]
        } else {
            self.entry = []
        }
    }
}

public struct ITunesRSSLabelDTO: Decodable, Sendable {
    public let label: String?
}

public struct ITunesRSSImageDTO: Decodable, Sendable {
    public let label: String?
}

public struct ITunesRSSIDAttributesDTO: Decodable, Sendable {
    public let imId: String?

    enum CodingKeys: String, CodingKey {
        case imId = "im:id"
    }
}

public struct ITunesRSSIDDTO: Decodable, Sendable {
    public let label: String?
    public let attributes: ITunesRSSIDAttributesDTO?
}

public struct ITunesRSSCategoryAttributesDTO: Decodable, Sendable {
    public let imId: String?
    public let label: String?
    public let term: String?

    enum CodingKeys: String, CodingKey {
        case imId = "im:id"
        case label
        case term
    }
}

public struct ITunesRSSCategoryDTO: Decodable, Sendable {
    public let attributes: ITunesRSSCategoryAttributesDTO?
}

public struct ITunesRSSLinkAttributesDTO: Decodable, Sendable {
    public let rel: String?
    public let type: String?
    public let href: String?
    public let title: String?
}

public struct ITunesRSSLinkItemDTO: Decodable, Sendable {
    public let attributes: ITunesRSSLinkAttributesDTO?
    public let duration: ITunesRSSLabelDTO?

    enum CodingKeys: String, CodingKey {
        case attributes
        case duration = "im:duration"
    }
}

public struct ITunesRSSEntryDTO: Decodable, Sendable {
    public let name: ITunesRSSLabelDTO?
    public let images: [ITunesRSSImageDTO]?
    public let summary: ITunesRSSLabelDTO?
    public let title: ITunesRSSLabelDTO?
    public let id: ITunesRSSIDDTO?
    public let artist: ITunesRSSLabelDTO?
    public let category: ITunesRSSCategoryDTO?
    public let releaseDate: ITunesRSSLabelDTO?
    public let links: [ITunesRSSLinkItemDTO]

    enum CodingKeys: String, CodingKey {
        case name = "im:name"
        case images = "im:image"
        case summary
        case title
        case id
        case artist = "im:artist"
        case category
        case releaseDate = "im:releaseDate"
        case link
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try? c.decode(ITunesRSSLabelDTO.self, forKey: .name)
        self.images = try? c.decode([ITunesRSSImageDTO].self, forKey: .images)
        self.summary = try? c.decode(ITunesRSSLabelDTO.self, forKey: .summary)
        self.title = try? c.decode(ITunesRSSLabelDTO.self, forKey: .title)
        self.id = try? c.decode(ITunesRSSIDDTO.self, forKey: .id)
        self.artist = try? c.decode(ITunesRSSLabelDTO.self, forKey: .artist)
        self.category = try? c.decode(ITunesRSSCategoryDTO.self, forKey: .category)
        self.releaseDate = try? c.decode(ITunesRSSLabelDTO.self, forKey: .releaseDate)
        if let arr = try? c.decode([ITunesRSSLinkItemDTO].self, forKey: .link) {
            self.links = arr
        } else if let single = try? c.decode(ITunesRSSLinkItemDTO.self, forKey: .link) {
            self.links = [single]
        } else {
            self.links = []
        }
    }
}

// MARK: - Apple iTunes Search & Lookup DTOs

public struct ITunesSearchResponseDTO: Decodable, Sendable {
    public let resultCount: Int?
    public let results: [ITunesTrackDTO]?
}

public struct ITunesTrackDTO: Decodable, Sendable {
    public let wrapperType: String?
    public let kind: String?
    public let trackId: Int?
    public let collectionId: Int?
    public let trackName: String?
    public let collectionName: String?
    public let artistName: String?
    public let trackViewUrl: String?
    public let previewUrl: String?
    public let artworkUrl100: String?
    public let releaseDate: String?
    public let trackTimeMillis: Int?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let country: String?
    public let primaryGenreName: String?
    public let contentAdvisoryRating: String?
    public let shortDescription: String?
    public let longDescription: String?
}
