import Foundation

public enum MediaMerger {
    public static func merge(_ items: [MediaItem]) -> [MediaItem] {
        var mergedList: [MediaItem] = []
        var keyToIndex: [String: Int] = [:]

        for item in items {
            let candidateKeys = allLookupKeys(for: item)
            if let existingIndex = candidateKeys.compactMap({ keyToIndex[$0] }).first {
                let updated = combine(mergedList[existingIndex], with: item)
                mergedList[existingIndex] = updated
                for key in allLookupKeys(for: updated) {
                    keyToIndex[key] = existingIndex
                }
            } else {
                let newIndex = mergedList.count
                mergedList.append(item)
                for key in candidateKeys {
                    keyToIndex[key] = newIndex
                }
            }
        }

        return mergedList
    }

    private static func allLookupKeys(for item: MediaItem) -> [String] {
        let kindGroup = item.projectType.isEpisodic ? "ep" : "single"
        let yearPart = item.releaseYear > 0 ? String(item.releaseYear) : "0"

        var rawTitles = [item.localizedTitle, item.originalTitle] + item.alternativeTitles
        rawTitles = rawTitles.map { $0.normalizedForComparison }.filter { !$0.isEmpty }

        var keys: [String] = ["id|\(item.id)"]
        for (source, extID) in item.externalIDs where !extID.isEmpty {
            keys.append("ext|\(source.rawValue)|\(extID.lowercased())")
        }
        for norm in Set(rawTitles) {
            keys.append("\(kindGroup)|\(norm)|\(yearPart)")
        }
        return keys
    }

    private static func combine(_ first: MediaItem, with second: MediaItem) -> MediaItem {
        let rank: (MediaItem) -> Int = { item in
            switch item.primarySource {
            case .openCinema: return 6
            case .tmdb: return 5
            case .aniList: return (item.projectType == .anime || item.projectType == .animeMovie) ? 6 : 4
            case .tvMaze: return item.projectType.isEpisodic ? 4 : 3
            case .internetArchive: return 2
            case .wikidata: return 1
            }
        }
        let preferSecond = rank(second) > rank(first)

        let primary = preferSecond ? second : first
        let secondary = preferSecond ? first : second

        var combinedRatings = primary.ratings
        if let s = secondary.ratings.tmdbScore, combinedRatings.tmdbScore == nil { combinedRatings.tmdbScore = s }
        if let s = secondary.ratings.aniListScore, combinedRatings.aniListScore == nil { combinedRatings.aniListScore = s }
        if let s = secondary.ratings.tvMazeScore, combinedRatings.tvMazeScore == nil { combinedRatings.tvMazeScore = s }
        if let v = secondary.ratings.voteCount, combinedRatings.voteCount == nil { combinedRatings.voteCount = v }

        var combinedExternalIDs = secondary.externalIDs
        for (k, v) in primary.externalIDs { combinedExternalIDs[k] = v }

        let mergedGenres = deduplicatedStrings(primary.genres + secondary.genres)
        let mergedAltTitles = deduplicatedStrings(
            primary.alternativeTitles
                + secondary.alternativeTitles
                + [secondary.localizedTitle, secondary.originalTitle]
        ).filter {
            $0.caseInsensitiveCompare(primary.localizedTitle) != .orderedSame
                && $0.caseInsensitiveCompare(primary.originalTitle) != .orderedSame
        }

        let synopsis: String = {
            let pClean = primary.synopsis
            let sClean = secondary.synopsis
            if pClean.isEmpty || pClean == "No description available." { return sClean }
            return pClean.count >= sClean.count ? pClean : sClean
        }()

        let director: String = {
            let generic = ["Unknown Director", "Series Creator", "Animation Studio", "Network Production"]
            if generic.contains(primary.director) && !generic.contains(secondary.director) && !secondary.director.isEmpty {
                return secondary.director
            }
            return primary.director
        }()

        let studio = primary.studio.nilIfEmpty ?? secondary.studio
        let mergedCast = primary.cast.isEmpty ? secondary.cast : primary.cast
        let mergedSeasons = primary.seasons.isEmpty ? secondary.seasons : primary.seasons

        var seenLinks = Set<String>()
        let mergedLinks = (primary.officialPlatformLinks + secondary.officialPlatformLinks).filter {
            seenLinks.insert($0.url.absoluteString.lowercased()).inserted
        }

        return MediaItem(
            id: primary.id,
            externalIDs: combinedExternalIDs,
            primarySource: primary.primarySource,
            projectType: primary.projectType,
            localizedTitle: primary.localizedTitle,
            originalTitle: primary.originalTitle,
            synopsis: synopsis,
            releaseYear: primary.releaseYear > 0 ? primary.releaseYear : secondary.releaseYear,
            releaseDate: primary.releaseDate ?? secondary.releaseDate,
            countryOfOrigin: primary.countryOfOrigin,
            originalLanguage: primary.originalLanguage,
            ageRating: primary.ageRating,
            genres: mergedGenres,
            durationMinutes: primary.durationMinutes > 0 ? primary.durationMinutes : secondary.durationMinutes,
            totalSeasons: max(primary.totalSeasons, secondary.totalSeasons),
            totalEpisodes: max(primary.totalEpisodes, secondary.totalEpisodes),
            releaseStatus: primary.releaseStatus,
            ratings: combinedRatings,
            popularityScore: max(primary.popularityScore, secondary.popularityScore),
            posterURL: primary.posterURL ?? secondary.posterURL,
            backdropURL: primary.backdropURL ?? secondary.backdropURL,
            bannerAccentHex: primary.bannerAccentHex ?? secondary.bannerAccentHex,
            director: director,
            studio: studio,
            alternativeTitles: mergedAltTitles,
            cast: mergedCast,
            seasons: mergedSeasons,
            trailerURL: primary.trailerURL ?? secondary.trailerURL,
            officialPlatformLinks: mergedLinks,
            similarProjectIDs: deduplicatedStrings(primary.similarProjectIDs + secondary.similarProjectIDs),
            nextAiringEpisodeNumber: primary.nextAiringEpisodeNumber ?? secondary.nextAiringEpisodeNumber,
            nextAiringDate: primary.nextAiringDate ?? secondary.nextAiringDate
        )
    }

    private static func deduplicatedStrings(_ list: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in list {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
