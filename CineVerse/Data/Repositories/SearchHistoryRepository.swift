import Foundation
import SwiftData

@MainActor
public protocol SearchHistoryRepositoryProtocol: AnyObject {
    func recentQueries(limit: Int) -> [SearchHistoryRecord]
    func saveQuery(_ query: String)
    func deleteQuery(_ normalizedQuery: String)
    func clearAll()
}

@MainActor
public final class SearchHistoryRepository: SearchHistoryRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func recentQueries(limit: Int = 20) -> [SearchHistoryRecord] {
        var descriptor = FetchDescriptor<SearchHistoryRecord>(
            sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func saveQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.lowercased()

        let descriptor = FetchDescriptor<SearchHistoryRecord>(
            predicate: #Predicate { $0.normalizedQuery == normalized }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.query = trimmed
            existing.searchedAt = Date()
        } else {
            let record = SearchHistoryRecord(query: trimmed)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    public func deleteQuery(_ normalizedQuery: String) {
        let descriptor = FetchDescriptor<SearchHistoryRecord>(
            predicate: #Predicate { $0.normalizedQuery == normalizedQuery }
        )
        if let match = try? modelContext.fetch(descriptor).first {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }

    public func clearAll() {
        let all = (try? modelContext.fetch(FetchDescriptor<SearchHistoryRecord>())) ?? []
        for item in all {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
