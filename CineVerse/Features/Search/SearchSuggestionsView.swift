import SwiftUI

public struct SearchSuggestionsView: View {
    let matchingHistory: [SearchHistoryRecord]
    let suggestions: [String]

    public init(matchingHistory: [SearchHistoryRecord], suggestions: [String]) {
        self.matchingHistory = matchingHistory
        self.suggestions = suggestions
    }

    private var filteredSuggestions: [String] {
        let historySet = Set(matchingHistory.map { $0.query.lowercased() })
        return suggestions.filter { !historySet.contains($0.lowercased()) }
    }

    public var body: some View {
        if !matchingHistory.isEmpty {
            Section("Recent Searches") {
                ForEach(matchingHistory, id: \.normalizedQuery) { record in
                    Label(record.query, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.primary)
                        .searchCompletion(record.query)
                }
            }
        }

        if !filteredSuggestions.isEmpty {
            Section("Suggestions") {
                ForEach(filteredSuggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "magnifyingglass")
                        .foregroundStyle(.primary)
                        .searchCompletion(suggestion)
                }
            }
        }
    }
}
