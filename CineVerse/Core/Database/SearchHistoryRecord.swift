import Foundation
import SwiftData

@Model
public final class SearchHistoryRecord {
    @Attribute(.unique) public var normalizedQuery: String
    public var query: String
    public var searchedAt: Date

    public init(query: String, searchedAt: Date = Date()) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedQuery = trimmed.lowercased()
        self.query = trimmed
        self.searchedAt = searchedAt
    }

    public func toDTO() -> SearchHistoryDTO {
        SearchHistoryDTO(query: query, searchedAt: searchedAt)
    }
}
