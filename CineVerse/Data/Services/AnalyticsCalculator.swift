import Foundation

public enum AnalyticsCalculator {
    public static func calculate(
        entries: [LibraryEntryRecord],
        progress: [PlaybackProgressRecord],
        history: [WatchHistoryRecord]
    ) -> TrackerAnalyticsSnapshot {
        let completedOrWatching = entries.filter {
            $0.status == .completed || $0.status == .watching || $0.status == .rewatching
        }
        let completedEntries = entries.filter { $0.status == .completed }

        let totalMovies = completedEntries.filter {
            $0.projectType == .movie || $0.projectType == .animeMovie || $0.projectType == .cartoonMovie || $0.projectType == .documentary
        }.count

        let totalAnime = completedEntries.filter {
            $0.projectType == .anime || $0.projectType == .animeMovie
        }.count

        let totalSeries = completedEntries.filter {
            $0.projectType == .tvSeries || $0.projectType == .cartoonSeries || $0.projectType == .drama
        }.count

        let watchedEpisodesCount = progress.filter { $0.isWatched && $0.episode > 0 }.count
        let seasonsCompleted = completedEntries.filter { $0.projectType.isEpisodic }.reduce(0) {
            $0 + max($1.totalSeasons, 1)
        }

        let totalMinutes = history.reduce(0) { $0 + max($1.minutesWatched, 0) }
        let totalHours = Double(totalMinutes) / 60.0

        let scoredEntries = entries.compactMap(\.personalRating)
        let avgScore = scoredEntries.isEmpty
            ? 0.0
            : scoredEntries.reduce(0.0, +) / Double(scoredEntries.count)

        var statusBreakdown: [WatchTrackingStatus: Int] = [:]
        for status in WatchTrackingStatus.allCases {
            statusBreakdown[status] = entries.filter { $0.status == status }.count
        }

        let topGenres = computeGenreStats(entries: entries, history: history)
        let monthlyActivity = computeMonthlyActivity(history: history)
        let categoryBreakdown = computeCategoryStats(entries: completedOrWatching, history: history)

        return TrackerAnalyticsSnapshot(
            totalProjectsWatched: completedEntries.count,
            totalMoviesWatched: totalMovies,
            totalSeriesWatched: totalSeries,
            totalAnimeWatched: totalAnime,
            totalEpisodesWatched: watchedEpisodesCount,
            totalSeasonsCompleted: seasonsCompleted,
            totalHoursWatched: totalHours,
            averagePersonalScore: avgScore,
            statusBreakdown: statusBreakdown,
            topGenres: topGenres,
            monthlyActivity: monthlyActivity,
            categoryBreakdown: categoryBreakdown
        )
    }

    public static func dailyActivity(from history: [WatchHistoryRecord], days: Int = 30) -> [DailyWatchActivityPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: history) { calendar.startOfDay(for: $0.watchedAt) }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d MMM"

        var points: [DailyWatchActivityPoint] = []
        for offset in stride(from: -(days - 1), through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let mins = (grouped[date] ?? []).reduce(0) { $0 + $1.minutesWatched }
            points.append(
                DailyWatchActivityPoint(
                    date: date,
                    dayLabel: dayFormatter.string(from: date),
                    minutesWatched: mins
                )
            )
        }
        return points
    }

    private static func computeGenreStats(
        entries: [LibraryEntryRecord],
        history: [WatchHistoryRecord]
    ) -> [GenreStatPoint] {
        var counts: [String: Int] = [:]
        var ratings: [String: [Double]] = [:]
        var minutes: [String: Int] = [:]

        for entry in entries {
            for genre in entry.genres {
                counts[genre, default: 0] += 1
                if let rating = entry.personalRating {
                    ratings[genre, default: []].append(rating)
                }
            }
        }

        for item in history {
            for genre in item.genres {
                minutes[genre, default: 0] += item.minutesWatched
            }
        }

        return counts.keys.map { genre in
            let genreRatings = ratings[genre] ?? []
            let avg = genreRatings.isEmpty ? 0 : genreRatings.reduce(0, +) / Double(genreRatings.count)
            return GenreStatPoint(
                genre: genre,
                projectCount: counts[genre] ?? 0,
                hoursWatched: Double(minutes[genre] ?? 0) / 60.0,
                averagePersonalRating: avg
            )
        }
        .sorted {
            if $0.projectCount != $1.projectCount {
                return $0.projectCount > $1.projectCount
            }
            return $0.hoursWatched > $1.hoursWatched
        }
        .prefix(8)
        .map { $0 }
    }

    private static func computeMonthlyActivity(history: [WatchHistoryRecord]) -> [MonthlyWatchActivityPoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [MonthlyWatchActivityPoint] = []

        for offset in stride(from: -11, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .month, value: offset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            let year = comps.year ?? 2026
            let month = comps.month ?? 1
            let label = CineVerseDateFormatters.monthShort.string(from: date)

            let monthRecords = history.filter { record in
                let rc = calendar.dateComponents([.year, .month], from: record.watchedAt)
                return rc.year == year && rc.month == month
            }

            let hours = Double(monthRecords.reduce(0) { $0 + $1.minutesWatched }) / 60.0
            let episodes = monthRecords.filter { $0.episode != nil }.count
            points.append(
                MonthlyWatchActivityPoint(
                    monthLabel: label,
                    year: year,
                    month: month,
                    hoursWatched: hours,
                    episodesCount: episodes
                )
            )
        }
        return points
    }

    private static func computeCategoryStats(
        entries: [LibraryEntryRecord],
        history: [WatchHistoryRecord]
    ) -> [CategoryStatPoint] {
        var counts: [MediaProjectType: Int] = [:]
        var minutes: [MediaProjectType: Int] = [:]

        for entry in entries {
            counts[entry.projectType, default: 0] += 1
        }
        for item in history {
            minutes[item.projectType, default: 0] += item.minutesWatched
        }

        return counts.map { category, count in
            CategoryStatPoint(
                category: category,
                count: count,
                hoursWatched: Double(minutes[category] ?? 0) / 60.0
            )
        }
        .sorted { $0.count > $1.count }
    }
}
