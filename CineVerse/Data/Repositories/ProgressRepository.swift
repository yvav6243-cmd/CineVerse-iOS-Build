import Foundation
import SwiftData

@MainActor
public protocol ProgressRepositoryProtocol: AnyObject {
    func progress(mediaID: String, season: Int, episode: Int) -> PlaybackProgressRecord?
    func allProgress(for mediaID: String) -> [PlaybackProgressRecord]
    @discardableResult
    func savePlaybackPosition(
        item: MediaItem,
        season: Int,
        episode: Int,
        episodeTitle: String,
        positionSeconds: Double,
        durationSeconds: Double,
        sourceID: String?
    ) -> PlaybackProgressRecord
    func markWatched(
        item: MediaItem,
        season: Int,
        episode: Int,
        episodeTitle: String,
        durationMinutes: Int,
        watched: Bool
    )
    func continueWatchingItems() -> [(entry: LibraryEntryRecord, progress: PlaybackProgressRecord)]
    func recentlyWatchedItems(limit: Int) -> [MediaItem]
    func watchHistory(limit: Int?) -> [WatchHistoryRecord]
    func recordHistory(
        mediaID: String,
        title: String,
        projectType: MediaProjectType,
        genres: [String],
        season: Int?,
        episode: Int?,
        minutes: Int
    )
}

@MainActor
public final class ProgressRepository: ProgressRepositoryProtocol {
    private let modelContext: ModelContext
    private let libraryRepository: LibraryRepositoryProtocol

    public init(modelContext: ModelContext, libraryRepository: LibraryRepositoryProtocol) {
        self.modelContext = modelContext
        self.libraryRepository = libraryRepository
    }

    public func progress(mediaID: String, season: Int, episode: Int) -> PlaybackProgressRecord? {
        let key = PlaybackProgressRecord.makeKey(mediaID: mediaID, season: season, episode: episode)
        let descriptor = FetchDescriptor<PlaybackProgressRecord>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    public func allProgress(for mediaID: String) -> [PlaybackProgressRecord] {
        let descriptor = FetchDescriptor<PlaybackProgressRecord>(
            predicate: #Predicate { $0.mediaID == mediaID },
            sortBy: [
                SortDescriptor(\.season, order: .forward),
                SortDescriptor(\.episode, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    public func savePlaybackPosition(
        item: MediaItem,
        season: Int,
        episode: Int,
        episodeTitle: String,
        positionSeconds: Double,
        durationSeconds: Double,
        sourceID: String?
    ) -> PlaybackProgressRecord {
        _ = libraryRepository.upsert(from: item)

        let record: PlaybackProgressRecord
        if let existing = progress(mediaID: item.id, season: season, episode: episode) {
            record = existing
        } else {
            record = PlaybackProgressRecord(
                mediaID: item.id,
                season: season,
                episode: episode,
                episodeTitle: episodeTitle
            )
            modelContext.insert(record)
        }

        record.episodeTitle = episodeTitle
        record.positionSeconds = max(0, positionSeconds)
        if durationSeconds > 1 {
            record.durationSeconds = durationSeconds
        }
        record.sourceID = sourceID
        record.lastUpdated = Date()
        if record.fraction >= 0.90 && !record.isWatched {
            record.isWatched = true
            record.watchedAt = Date()
        }

        saveChanges()
        return record
    }

    public func markWatched(
        item: MediaItem,
        season: Int,
        episode: Int,
        episodeTitle: String,
        durationMinutes: Int,
        watched: Bool
    ) {
        _ = libraryRepository.upsert(from: item)

        let record: PlaybackProgressRecord
        if let existing = progress(mediaID: item.id, season: season, episode: episode) {
            record = existing
        } else {
            record = PlaybackProgressRecord(
                mediaID: item.id,
                season: season,
                episode: episode,
                episodeTitle: episodeTitle,
                durationSeconds: Double(max(durationMinutes, 1) * 60)
            )
            modelContext.insert(record)
        }

        record.isWatched = watched
        record.watchedAt = watched ? Date() : nil
        record.lastUpdated = Date()
        if watched && record.durationSeconds > 0 {
            record.positionSeconds = record.durationSeconds
        } else if !watched {
            record.positionSeconds = 0
        }
        saveChanges()
    }

    public func continueWatchingItems() -> [(entry: LibraryEntryRecord, progress: PlaybackProgressRecord)] {
        let descriptor = FetchDescriptor<PlaybackProgressRecord>(
            predicate: #Predicate { $0.isWatched == false },
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        var seenMediaIDs: Set<String> = []
        var result: [(entry: LibraryEntryRecord, progress: PlaybackProgressRecord)] = []

        for prog in records {
            let frac = prog.fraction
            guard frac >= 0.02 && frac <= 0.92 else { continue }
            guard seenMediaIDs.insert(prog.mediaID).inserted else { continue }
            if let entry = libraryRepository.entry(for: prog.mediaID) {
                result.append((entry, prog))
            }
            if result.count >= 20 { break }
        }
        return result
    }

    public func recentlyWatchedItems(limit: Int = 20) -> [MediaItem] {
        let history = watchHistory(limit: 80)
        var seen: Set<String> = []
        var items: [MediaItem] = []

        for record in history {
            guard seen.insert(record.mediaID).inserted else { continue }
            if let entry = libraryRepository.entry(for: record.mediaID) {
                if let snap = entry.snapshot {
                    items.append(snap)
                } else {
                    items.append(
                        MediaItem(
                            id: entry.mediaID,
                            primarySource: MediaReference(id: entry.mediaID)?.provider ?? .openCinema,
                            projectType: entry.projectType,
                            localizedTitle: entry.title,
                            originalTitle: entry.originalTitle,
                            synopsis: entry.notes,
                            releaseYear: entry.releaseYear,
                            countryOfOrigin: "US",
                            originalLanguage: "en",
                            genres: entry.genres,
                            durationMinutes: entry.episodeDurationMinutes,
                            totalSeasons: entry.totalSeasons,
                            totalEpisodes: entry.totalEpisodes,
                            ratings: MultiSourceRatings(),
                            posterURL: entry.posterURL,
                            backdropURL: entry.backdropURL
                        )
                    )
                }
            }
            if items.count >= limit { break }
        }
        return items
    }

    public func watchHistory(limit: Int? = nil) -> [WatchHistoryRecord] {
        var descriptor = FetchDescriptor<WatchHistoryRecord>(
            sortBy: [SortDescriptor(\.watchedAt, order: .reverse)]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func recordHistory(
        mediaID: String,
        title: String,
        projectType: MediaProjectType,
        genres: [String],
        season: Int?,
        episode: Int?,
        minutes: Int
    ) {
        let entry = WatchHistoryRecord(
            mediaID: mediaID,
            title: title,
            projectTypeRaw: projectType.rawValue,
            genres: genres,
            season: season,
            episode: episode,
            minutesWatched: max(minutes, 1),
            watchedAt: Date()
        )
        modelContext.insert(entry)
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            CVLogger.database.error("Progress save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
