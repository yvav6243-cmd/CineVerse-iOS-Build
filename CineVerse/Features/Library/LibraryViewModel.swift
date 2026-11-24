import Foundation
import SwiftData
import Observation

public enum LibrarySection: String, CaseIterable, Identifiable, Sendable {
    case watchlist = "Watchlist"
    case favorites = "Favorites"
    case watching = "Watching"
    case completed = "Completed"
    case onHold = "On Hold"
    case dropped = "Dropped"
    case collections = "Collections"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .watchlist: return "bookmark.fill"
        case .favorites: return "heart.fill"
        case .watching: return "play.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .onHold: return "pause.circle.fill"
        case .dropped: return "xmark.circle.fill"
        case .collections: return "rectangle.stack.fill"
        }
    }
}

public enum LibrarySortOption: String, CaseIterable, Identifiable, Sendable {
    case recentlyUpdated = "Recently Updated"
    case dateAdded = "Date Added"
    case title = "Title"
    case releaseYear = "Release Year"
    case personalRating = "Personal Rating"

    public var id: String { rawValue }
}

@MainActor
@Observable
public final class LibraryViewModel {
    private let container: AppContainer

    public var entries: [LibraryEntryRecord] = []
    public var collections: [CustomCollectionRecord] = []
    public var progressByMediaID: [String: Double] = [:]

    public var selectedSection: LibrarySection = .watchlist
    public var sortOption: LibrarySortOption = .recentlyUpdated
    public var selectedProjectType: MediaProjectType? = nil
    public var isGridLayout: Bool = true
    public var searchText: String = ""

    public init(container: AppContainer) {
        self.container = container
    }

    public func reload() {
        entries = container.libraryRepository.allEntries()
        collections = container.collectionsRepository.allCollections()

        let context = container.modelContainer.mainContext
        let allProgress = (try? context.fetch(FetchDescriptor<PlaybackProgressRecord>())) ?? []
        let grouped = Dictionary(grouping: allProgress, by: \.mediaID)

        var map: [String: Double] = [:]
        for entry in entries {
            let records = grouped[entry.mediaID] ?? []
            if entry.projectType.isEpisodic {
                let watched = records.filter(\.isWatched).count
                let total = max(entry.totalEpisodes, watched, 1)
                let fraction = Double(watched) / Double(total)
                if fraction > 0 {
                    map[entry.mediaID] = min(fraction, 1.0)
                }
            } else if records.contains(where: \.isWatched) || entry.status == .completed {
                map[entry.mediaID] = 1.0
            } else if let first = records.first, first.fraction > 0.01 {
                map[entry.mediaID] = first.fraction
            }
        }
        progressByMediaID = map
    }

    public var filteredEntries: [LibraryEntryRecord] {
        let base: [LibraryEntryRecord]
        switch selectedSection {
        case .watchlist:
            base = entries.filter { $0.inWatchlist || $0.status == .planning }
        case .favorites:
            base = entries.filter(\.isFavorite)
        case .watching:
            base = entries.filter { $0.status == .watching || $0.status == .rewatching }
        case .completed:
            base = entries.filter { $0.status == .completed }
        case .onHold:
            base = entries.filter { $0.status == .onHold }
        case .dropped:
            base = entries.filter { $0.status == .dropped }
        case .collections:
            base = []
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = base.filter { entry in
            if let typeFilter = selectedProjectType, entry.projectType != typeFilter {
                return false
            }
            if !query.isEmpty {
                let matchesTitle = entry.title.lowercased().contains(query)
                let matchesOriginal = entry.originalTitle.lowercased().contains(query)
                return matchesTitle || matchesOriginal
            }
            return true
        }

        return filtered.sorted { lhs, rhs in
            switch sortOption {
            case .recentlyUpdated:
                return lhs.updatedAt > rhs.updatedAt
            case .dateAdded:
                return lhs.addedAt > rhs.addedAt
            case .title:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .releaseYear:
                if lhs.releaseYear != rhs.releaseYear {
                    return lhs.releaseYear > rhs.releaseYear
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .personalRating:
                let leftScore = lhs.personalRating ?? -1
                let rightScore = rhs.personalRating ?? -1
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    public func toggleFavorite(_ entry: LibraryEntryRecord) {
        entry.isFavorite.toggle()
        entry.updatedAt = Date()
        container.libraryRepository.saveChanges()
        reload()
    }

    public func toggleWatchlist(_ entry: LibraryEntryRecord) {
        entry.inWatchlist.toggle()
        entry.updatedAt = Date()
        container.libraryRepository.saveChanges()
        reload()
    }

    public func setStatus(_ status: WatchTrackingStatus?, for entry: LibraryEntryRecord) {
        container.libraryRepository.setStatus(status, mediaID: entry.mediaID)
        reload()
    }

    public func deleteEntry(_ entry: LibraryEntryRecord) {
        container.libraryRepository.deleteEntry(mediaID: entry.mediaID)
        reload()
    }

    public func createCollection(name: String, symbolName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = container.collectionsRepository.createCollection(name: trimmed, symbolName: symbolName)
        reload()
    }

    public func renameCollection(_ collection: CustomCollectionRecord, name: String, symbolName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        container.collectionsRepository.renameCollection(id: collection.id, name: trimmed, symbolName: symbolName)
        reload()
    }

    public func deleteCollection(_ collection: CustomCollectionRecord) {
        container.collectionsRepository.deleteCollection(id: collection.id)
        reload()
    }
}
