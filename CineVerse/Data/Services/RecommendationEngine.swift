import Foundation

public struct TasteProfile: Sendable {
    public let genreWeights: [String: Double]
    public let typeWeights: [MediaProjectType: Double]
    public let excludedMediaIDs: Set<String>

    public var isEmpty: Bool {
        genreWeights.isEmpty && typeWeights.isEmpty
    }

    public var topGenres: [String] {
        genreWeights
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }
}

public enum RecommendationScorer {
    public static func buildProfile(from entries: [LibraryEntryRecord]) -> TasteProfile {
        let snapshots = entries.map { entry in
            TasteEntrySnapshot(
                mediaID: entry.mediaID,
                projectType: entry.projectType,
                genres: entry.genres,
                status: entry.status,
                isFavorite: entry.isFavorite,
                personalRating: entry.personalRating
            )
        }
        return buildProfile(fromSnapshots: snapshots)
    }

    public static func buildProfile(fromSnapshots entries: [TasteEntrySnapshot]) -> TasteProfile {
        var genreWeights: [String: Double] = [:]
        var typeWeights: [MediaProjectType: Double] = [:]
        var excluded: Set<String> = []

        for entry in entries {
            excluded.insert(entry.mediaID)

            var weight = 0.0
            if entry.isFavorite { weight += 3.0 }
            if let rating = entry.personalRating {
                weight += (rating - 5.0) * 0.6
            }
            switch entry.status {
            case .completed: weight += 1.5
            case .watching, .rewatching: weight += 1.0
            case .onHold: weight += 0.2
            case .planning: weight += 0.3
            case .dropped: weight -= 2.0
            case nil: break
            }

            if weight != 0 {
                typeWeights[entry.projectType, default: 0] += weight
                for genre in entry.genres {
                    genreWeights[genre.lowercased(), default: 0] += weight
                }
            }
        }

        return TasteProfile(
            genreWeights: genreWeights,
            typeWeights: typeWeights,
            excludedMediaIDs: excluded
        )
    }

    public static func rank(candidates: [MediaItem], profile: TasteProfile) -> [MediaItem] {
        let filtered = candidates.filter { !profile.excludedMediaIDs.contains($0.id) }
        guard !profile.isEmpty else {
            return filtered.sorted { $0.displayRating > $1.displayRating }
        }

        let maxPop = max(filtered.map(\.popularityScore).max() ?? 1.0, 1.0)
        let profileNorm = sqrt(profile.genreWeights.values.reduce(0.0) { $0 + $1 * $1 })
        let maxTypeAbs = max(profile.typeWeights.values.map(abs).max() ?? 1.0, 1.0)

        let scored: [(item: MediaItem, score: Double)] = filtered.map { item in
            let itemGenres = Set(item.genres.map { $0.lowercased() })
            var dot = 0.0
            for g in itemGenres {
                dot += profile.genreWeights[g] ?? 0.0
            }
            let genreCosine = (profileNorm > 0 && !itemGenres.isEmpty)
                ? dot / (profileNorm * sqrt(Double(itemGenres.count)))
                : 0.0

            let normalizedRating = min(max(item.displayRating / 10.0, 0), 1)
            let normalizedPopularity = min(max(item.popularityScore / maxPop, 0), 1)
            let rawTypeAffinity = profile.typeWeights[item.projectType] ?? 0.0
            let typeAffinity = (rawTypeAffinity / maxTypeAbs + 1.0) / 2.0

            let composite = 0.55 * genreCosine
                + 0.25 * normalizedRating
                + 0.10 * normalizedPopularity
                + 0.10 * typeAffinity

            return (item, composite)
        }

        return scored
            .sorted { $0.score > $1.score }
            .map(\.item)
    }
}

public struct TasteEntrySnapshot: Sendable {
    public let mediaID: String
    public let projectType: MediaProjectType
    public let genres: [String]
    public let status: WatchTrackingStatus?
    public let isFavorite: Bool
    public let personalRating: Double?

    public init(
        mediaID: String,
        projectType: MediaProjectType,
        genres: [String],
        status: WatchTrackingStatus?,
        isFavorite: Bool,
        personalRating: Double?
    ) {
        self.mediaID = mediaID
        self.projectType = projectType
        self.genres = genres
        self.status = status
        self.isFavorite = isFavorite
        self.personalRating = personalRating
    }
}

@MainActor
public final class RecommendationEngine {
    private let catalogRepository: CatalogRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private var cachedResult: (items: [MediaItem], timestamp: Date)?
    private let cacheDuration: TimeInterval = 6 * 3600

    public init(
        catalogRepository: CatalogRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol
    ) {
        self.catalogRepository = catalogRepository
        self.libraryRepository = libraryRepository
    }

    public func invalidateCache() {
        cachedResult = nil
    }

    public func recommendations(language: String, forceRefresh: Bool = false) async -> [MediaItem] {
        if !forceRefresh,
           let cached = cachedResult,
           Date().timeIntervalSince(cached.timestamp) <= cacheDuration {
            return cached.items
        }

        let entries = libraryRepository.allEntries()
        let profile = RecommendationScorer.buildProfile(from: entries)
        let topGenres = profile.topGenres

        var pool: [MediaItem] = []

        await withTaskGroup(of: [MediaItem].self) { group in
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.topRated, language: language)) ?? []
            }
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.popularAnime, language: language)) ?? []
            }
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.trendingMovies, language: language)) ?? []
            }
            group.addTask { [catalogRepository] in
                (try? await catalogRepository.homeFeed(.popularTVShows, language: language)) ?? []
            }

            // Only non-identifying genre names leave the device for public discovery
            for genre in topGenres {
                group.addTask { [catalogRepository] in
                    var criteria = CatalogFilterCriteria()
                    criteria.selectedGenres = [genre]
                    criteria.sortBy = .rating
                    return (try? await catalogRepository.discover(criteria: criteria, page: 1, language: language).items) ?? []
                }
            }

            for await batch in group {
                pool.append(contentsOf: batch)
            }
        }

        let deduplicated = MediaMerger.merge(pool)
        let ranked = Array(RecommendationScorer.rank(candidates: deduplicated, profile: profile).prefix(24))
        if !ranked.isEmpty {
            cachedResult = (ranked, Date())
        }
        return ranked
    }
}
