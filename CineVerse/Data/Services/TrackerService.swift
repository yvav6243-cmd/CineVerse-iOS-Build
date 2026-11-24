import Foundation
import Observation

@MainActor
@Observable
public final class TrackerService {
    private let libraryRepository: LibraryRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol

    public init(
        libraryRepository: LibraryRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol
    ) {
        self.libraryRepository = libraryRepository
        self.progressRepository = progressRepository
    }

    public func markEpisodeWatched(
        item: MediaItem,
        season: Int,
        episode: Int,
        episodeTitle: String,
        durationMinutes: Int,
        watched: Bool = true
    ) {
        let entry = libraryRepository.upsert(from: item)
        let previouslyWatched = progressRepository.progress(
            mediaID: item.id,
            season: season,
            episode: episode
        )?.isWatched ?? false

        progressRepository.markWatched(
            item: item,
            season: season,
            episode: episode,
            episodeTitle: episodeTitle,
            durationMinutes: durationMinutes,
            watched: watched
        )

        if watched && !previouslyWatched {
            progressRepository.recordHistory(
                mediaID: item.id,
                title: item.localizedTitle,
                projectType: item.projectType,
                genres: item.genres,
                season: item.projectType.isEpisodic ? season : nil,
                episode: item.projectType.isEpisodic ? episode : nil,
                minutes: max(durationMinutes, item.durationMinutes, 20)
            )
        }

        if watched {
            let watchedCount = progressRepository.allProgress(for: item.id).filter(\.isWatched).count
            let totalCount = max(entry.totalEpisodes, 1)

            if !item.projectType.isEpisodic || watchedCount >= totalCount {
                libraryRepository.setStatus(.completed, for: item)
            } else if entry.status == nil || entry.status == .planning {
                libraryRepository.setStatus(.watching, for: item)
            }
        }
    }

    public func markAllWatched(item: MediaItem) {
        let entry = libraryRepository.upsert(from: item)
        if item.projectType.isEpisodic {
            let seasons = item.seasons
            if !seasons.isEmpty {
                for season in seasons {
                    for ep in season.episodes {
                        progressRepository.markWatched(
                            item: item,
                            season: season.seasonNumber,
                            episode: ep.episodeNumber,
                            episodeTitle: ep.title,
                            durationMinutes: ep.durationMinutes,
                            watched: true
                        )
                    }
                }
            } else {
                for epNum in 1...max(entry.totalEpisodes, 1) {
                    progressRepository.markWatched(
                        item: item,
                        season: 1,
                        episode: epNum,
                        episodeTitle: "Episode \(epNum)",
                        durationMinutes: max(item.durationMinutes, 24),
                        watched: true
                    )
                }
            }
            progressRepository.recordHistory(
                mediaID: item.id,
                title: item.localizedTitle,
                projectType: item.projectType,
                genres: item.genres,
                season: 1,
                episode: entry.totalEpisodes,
                minutes: max(item.durationMinutes, 24) * max(entry.totalEpisodes, 1)
            )
        } else {
            let duration = max(item.durationMinutes, 90)
            progressRepository.markWatched(
                item: item,
                season: 0,
                episode: 0,
                episodeTitle: item.localizedTitle,
                durationMinutes: duration,
                watched: true
            )
            progressRepository.recordHistory(
                mediaID: item.id,
                title: item.localizedTitle,
                projectType: item.projectType,
                genres: item.genres,
                season: nil,
                episode: nil,
                minutes: duration
            )
        }

        libraryRepository.setStatus(.completed, for: item)
    }

    public func incrementNextEpisode(for entry: LibraryEntryRecord) {
        let progress = progressRepository.allProgress(for: entry.mediaID)
        let watchedCount = progress.filter(\.isWatched).count
        let nextNum = min(watchedCount + 1, max(entry.totalEpisodes, watchedCount + 1))

        let item = entry.snapshot ?? MediaItem(
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

        var targetSeason = 1
        var targetEpisode = nextNum
        var targetTitle = "Episode \(nextNum)"
        var targetMinutes = max(entry.episodeDurationMinutes, 24)

        let watchedKeys = Set(progress.filter(\.isWatched).map { "\($0.season):\($0.episode)" })
        outer: for season in item.seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }) {
            for ep in season.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                if !watchedKeys.contains("\(season.seasonNumber):\(ep.episodeNumber)") {
                    targetSeason = season.seasonNumber
                    targetEpisode = ep.episodeNumber
                    targetTitle = ep.title
                    targetMinutes = max(ep.durationMinutes, targetMinutes)
                    break outer
                }
            }
        }

        markEpisodeWatched(
            item: item,
            season: targetSeason,
            episode: targetEpisode,
            episodeTitle: targetTitle,
            durationMinutes: targetMinutes,
            watched: true
        )
    }

    public func nextEpisode(after current: MediaEpisode?, in item: MediaItem) -> MediaEpisode? {
        guard let current else {
            return item.seasons.first?.episodes.first
        }
        let sortedSeasons = item.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        guard let seasonIndex = sortedSeasons.firstIndex(where: { $0.seasonNumber == current.seasonNumber }) else {
            return nil
        }

        let seasonEpisodes = sortedSeasons[seasonIndex].episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        if let epIndex = seasonEpisodes.firstIndex(where: { $0.episodeNumber == current.episodeNumber }),
           epIndex + 1 < seasonEpisodes.count {
            return seasonEpisodes[epIndex + 1]
        }

        if seasonIndex + 1 < sortedSeasons.count {
            return sortedSeasons[seasonIndex + 1].episodes.sorted { $0.episodeNumber < $1.episodeNumber }.first
        }
        return nil
    }

    public func nextUnwatchedEpisode(for item: MediaItem) -> MediaEpisode? {
        let allProg = progressRepository.allProgress(for: item.id)
        let watchedKeys = Set(allProg.filter(\.isWatched).map { "\($0.season):\($0.episode)" })

        for season in item.seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }) {
            for ep in season.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                if !watchedKeys.contains("\(season.seasonNumber):\(ep.episodeNumber)") {
                    return ep
                }
            }
        }
        return item.seasons.first?.episodes.first
    }

    public func seasonProgress(for entry: LibraryEntryRecord) -> [(seasonNumber: Int, watched: Int, total: Int)] {
        let progress = progressRepository.allProgress(for: entry.mediaID)
        let watchedBySeason = Dictionary(grouping: progress.filter(\.isWatched), by: \.season)

        if let seasons = entry.snapshot?.seasons, !seasons.isEmpty {
            return seasons.sorted { $0.seasonNumber < $1.seasonNumber }.map { season in
                let total = max(season.episodeCount, season.episodes.count, 1)
                let watched = watchedBySeason[season.seasonNumber]?.count ?? 0
                return (season.seasonNumber, min(watched, total), total)
            }
        }

        let watchedTotal = progress.filter(\.isWatched).count
        return [(1, min(watchedTotal, entry.totalEpisodes), max(entry.totalEpisodes, 1))]
    }

    public func formattedProgress(for entry: LibraryEntryRecord) -> String {
        let progress = progressRepository.allProgress(for: entry.mediaID)
        let watchedItems = progress.filter(\.isWatched)
        if !entry.projectType.isEpisodic {
            if !watchedItems.isEmpty || entry.status == .completed {
                return "Completed"
            }
            if let active = progress.first, active.fraction > 0.01 {
                return "\(Int((active.fraction * 100).rounded()))%"
            }
            return entry.status?.rawValue ?? "Not Started"
        }

        let watchedCount = watchedItems.count
        let total = max(entry.totalEpisodes, watchedCount, 1)
        if entry.projectType == .anime {
            return "\(watchedCount)/\(total) episodes"
        }
        if let latest = watchedItems.max(by: { ($0.season, $0.episode) < ($1.season, $1.episode) }) {
            return "S\(latest.season) E\(latest.episode) • \(watchedCount)/\(total)"
        }
        return "\(watchedCount)/\(total) episodes"
    }
}
