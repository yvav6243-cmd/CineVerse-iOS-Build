import Foundation

public enum MediaMerger {
    public static func merge(_ items: [MediaItem]) -> [MediaItem] {
        var orderedKeys: [String] = []
        var mergedByKey: [String: MediaItem] = [:]

        for item in items {
            let key = dedupKey(for: item)
            if let existing = mergedByKey[key] {
                mergedByKey[key] = combine(existing, with: item)
            } else {
                orderedKeys.append(key)
                mergedByKey[key] = item
            }
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }

    private static func dedupKey(for item: MediaItem) -> String {
        let titleKey = item.localizedTitle.normalizedForComparison
        let bucketYear = item.releaseYear > 0 ? String(item.releaseYear) : "0"
        let kindGroup = item.projectType.isEpisodic ? "ep" : "single"
        return "\(kindGroup)|\(titleKey)|\(bucketYear)"
    }

    private static func combine(_ first: MediaItem, with second: MediaItem) -> MediaItem {
        let preferSecond: Bool
        if second.projectType == .anime || second.projectType == .animeMovie {
            preferSecond = second.primarySource == .aniList && first.primarySource != .aniList
        } else {
            preferSecond = second.primarySource == .tmdb && first.primarySource != .tmdb
        }

        var primary = preferSecond ? second : first
        let secondary = preferSecond ? first : second

        if let s = secondary.ratings.tmdbScore, primary.ratings.tmdbScore == nil {
            primary.ratings.tmdbScore = s
        }
        if let s = secondary.ratings.aniListScore, primary.ratings.aniListScore == nil {
            primary.ratings.aniListScore = s
        }
        if let s = secondary.ratings.tvMazeScore, primary.ratings.tvMazeScore == nil {
            primary.ratings.tvMazeScore = s
        }
        return primary
    }
}
