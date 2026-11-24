import Foundation
import SwiftData
import Observation

@MainActor
@Observable
public final class TrackerViewModel {
    private let container: AppContainer

    public var entries: [LibraryEntryRecord] = []
    public var progressRecords: [PlaybackProgressRecord] = []
    public var historyRecords: [WatchHistoryRecord] = []

    public var analytics: TrackerAnalyticsSnapshot = .empty
    public var dailyActivity: [DailyWatchActivityPoint] = []
    public var selectedStatus: WatchTrackingStatus = .watching

    public init(container: AppContainer) {
        self.container = container
    }

    public var currentlyWatchingEntries: [LibraryEntryRecord] {
        entries.filter { $0.status == .watching || $0.status == .rewatching }
    }

    public var filteredEntries: [LibraryEntryRecord] {
        entries.filter { $0.status == selectedStatus }
    }

    public func reload() {
        let context = container.modelContainer.mainContext
        entries = container.libraryRepository.allEntries()
        progressRecords = (try? context.fetch(FetchDescriptor<PlaybackProgressRecord>())) ?? []
        historyRecords = container.progressRepository.watchHistory(limit: nil)
        analytics = AnalyticsCalculator.calculate(
            entries: entries,
            progress: progressRecords,
            history: historyRecords
        )
        dailyActivity = AnalyticsCalculator.dailyActivity(from: historyRecords, days: 30)
    }

    public func incrementEpisode(for entry: LibraryEntryRecord) {
        container.trackerService.incrementNextEpisode(for: entry)
        reload()
        Task {
            await container.widgetWriter.refreshWidgets()
        }
    }

    public func formattedProgress(for entry: LibraryEntryRecord) -> String {
        container.trackerService.formattedProgress(for: entry)
    }

    public func progressFraction(for entry: LibraryEntryRecord) -> Double {
        let watchedCount = progressRecords.filter { $0.mediaID == entry.mediaID && $0.isWatched }.count
        if !entry.projectType.isEpisodic {
            if watchedCount > 0 || entry.status == .completed {
                return 1.0
            }
            return progressRecords.first(where: { $0.mediaID == entry.mediaID })?.fraction ?? 0.0
        }
        let total = max(entry.totalEpisodes, watchedCount, 1)
        return min(max(Double(watchedCount) / Double(total), 0.0), 1.0)
    }

    public func seasonProgress(for entry: LibraryEntryRecord) -> [(seasonNumber: Int, watched: Int, total: Int)] {
        container.trackerService.seasonProgress(for: entry)
    }

    public func setSeasonWatchedCount(
        _ newCount: Int,
        forSeason seasonNumber: Int,
        total: Int,
        in entry: LibraryEntryRecord
    ) {
        let clampedTarget = min(max(newCount, 0), max(total, 1))
        let allSeasonProgress = container.progressRepository
            .allProgress(for: entry.mediaID)
            .filter { $0.season == seasonNumber }

        let currentlyWatched = allSeasonProgress.filter(\.isWatched)
        let currentCount = currentlyWatched.count
        guard clampedTarget != currentCount else { return }

        let item = entry.resolvedMediaItem
        let seasonEpisodes = item.seasons
            .first(where: { $0.seasonNumber == seasonNumber })?
            .episodes
            .sorted { $0.episodeNumber < $1.episodeNumber } ?? []

        if clampedTarget > currentCount {
            let needed = clampedTarget - currentCount
            let watchedEpNumbers = Set(currentlyWatched.map(\.episode))
            let candidateNumbers: [Int] = seasonEpisodes.isEmpty
                ? Array(1...max(total, 1))
                : seasonEpisodes.map(\.episodeNumber)

            var marked = 0
            for epNum in candidateNumbers where !watchedEpNumbers.contains(epNum) {
                let meta = seasonEpisodes.first(where: { $0.episodeNumber == epNum })
                container.progressRepository.markWatched(
                    item: item,
                    season: seasonNumber,
                    episode: epNum,
                    episodeTitle: meta?.title ?? "Episode \(epNum)",
                    durationMinutes: max(meta?.durationMinutes ?? entry.episodeDurationMinutes, 1),
                    watched: true
                )
                marked += 1
                if marked >= needed { break }
            }
        } else {
            let toUnmark = currentCount - clampedTarget
            let descendingWatched = currentlyWatched.sorted { $0.episode > $1.episode }
            for record in descendingWatched.prefix(toUnmark) {
                container.progressRepository.markWatched(
                    item: item,
                    season: seasonNumber,
                    episode: record.episode,
                    episodeTitle: record.episodeTitle,
                    durationMinutes: max(entry.episodeDurationMinutes, 1),
                    watched: false
                )
            }
        }
        reload()
    }

    public func updateEntry(
        _ entry: LibraryEntryRecord,
        status: WatchTrackingStatus?,
        personalRating: Double?,
        startDate: Date?,
        finishDate: Date?,
        rewatchCount: Int,
        notes: String
    ) {
        if entry.status != status {
            container.libraryRepository.setStatus(status, mediaID: entry.mediaID)
        }
        container.libraryRepository.setPersonalRating(personalRating, mediaID: entry.mediaID)
        entry.startDate = startDate
        entry.finishDate = finishDate
        entry.rewatchCount = max(rewatchCount, 0)
        entry.notes = notes
        entry.updatedAt = Date()
        container.libraryRepository.saveChanges()
        reload()
    }

    public func updateStatus(_ status: WatchTrackingStatus?, for entry: LibraryEntryRecord) {
        container.libraryRepository.setStatus(status, mediaID: entry.mediaID)
        reload()
    }

    public func deleteEntry(_ entry: LibraryEntryRecord) {
        container.libraryRepository.deleteEntry(mediaID: entry.mediaID)
        reload()
        Task {
            await container.widgetWriter.refreshWidgets()
        }
    }
}

extension LibraryEntryRecord {
    var resolvedReference: MediaReference? {
        MediaReference(id: mediaID)
    }

    var resolvedMediaItem: MediaItem {
        if let snapshot {
            return snapshot
        }
        return MediaItem(
            id: mediaID,
            primarySource: MediaReference(id: mediaID)?.provider ?? .openCinema,
            projectType: projectType,
            localizedTitle: title,
            originalTitle: originalTitle,
            synopsis: notes,
            releaseYear: releaseYear,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: genres,
            durationMinutes: episodeDurationMinutes,
            totalSeasons: totalSeasons,
            totalEpisodes: totalEpisodes,
            ratings: MultiSourceRatings(),
            posterURL: posterURL,
            backdropURL: backdropURL
        )
    }
}
