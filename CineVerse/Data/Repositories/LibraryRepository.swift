import Foundation
import SwiftData

@MainActor
public protocol LibraryRepositoryProtocol: AnyObject {
    func entry(for mediaID: String) -> LibraryEntryRecord?
    func allEntries() -> [LibraryEntryRecord]
    func upsert(from item: MediaItem) -> LibraryEntryRecord
    func setStatus(_ status: WatchTrackingStatus?, for item: MediaItem)
    func setStatus(_ status: WatchTrackingStatus?, mediaID: String)
    @discardableResult
    func toggleFavorite(for item: MediaItem) -> Bool
    @discardableResult
    func toggleWatchlist(for item: MediaItem) -> Bool
    func setPersonalRating(_ rating: Double?, for item: MediaItem)
    func setPersonalRating(_ rating: Double?, mediaID: String)
    func setNotes(_ notes: String, for item: MediaItem)
    func setAlertsEnabled(_ enabled: Bool, mediaID: String)
    func savePlaybackPreferences(
        mediaID: String,
        sourceID: String?,
        audioLang: String?,
        subtitleLang: String?,
        quality: VideoQualityTier?
    )
    func savePreferredPlaybackRate(_ rate: Float, mediaID: String)
    func incrementRewatchCount(mediaID: String)
    func favorites() -> [MediaItem]
    func deleteEntry(mediaID: String)
    func saveChanges()
}

@MainActor
public final class LibraryRepository: LibraryRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func entry(for mediaID: String) -> LibraryEntryRecord? {
        let descriptor = FetchDescriptor<LibraryEntryRecord>(
            predicate: #Predicate { $0.mediaID == mediaID }
        )
        return try? modelContext.fetch(descriptor).first
    }

    public func allEntries() -> [LibraryEntryRecord] {
        let descriptor = FetchDescriptor<LibraryEntryRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    public func upsert(from item: MediaItem) -> LibraryEntryRecord {
        if let existing = entry(for: item.id) {
            existing.title = item.localizedTitle
            existing.originalTitle = item.originalTitle
            existing.projectType = item.projectType
            existing.posterURLString = item.posterURL?.absoluteString
            existing.backdropURLString = item.backdropURL?.absoluteString
            existing.genres = item.genres
            existing.releaseYear = item.releaseYear
            existing.totalEpisodes = max(item.totalEpisodes, 1)
            existing.totalSeasons = max(item.totalSeasons, 1)
            existing.episodeDurationMinutes = max(item.durationMinutes, existing.episodeDurationMinutes)
            let genericDirectors: Set<String> = ["Unknown Director", "Series Creator", "Animation Studio", "Network Production"]
            if !genericDirectors.contains(item.director) && !item.director.isEmpty {
                existing.directorName = item.director
            }
            if !item.studio.isEmpty {
                existing.studioName = item.studio
            }
            existing.snapshot = item
            existing.updatedAt = Date()
            saveChanges()
            return existing
        }

        let genericDirectors: Set<String> = ["Unknown Director", "Series Creator", "Animation Studio", "Network Production"]
        let created = LibraryEntryRecord(
            mediaID: item.id,
            title: item.localizedTitle,
            originalTitle: item.originalTitle,
            projectTypeRaw: item.projectType.rawValue,
            posterURLString: item.posterURL?.absoluteString,
            backdropURLString: item.backdropURL?.absoluteString,
            genres: item.genres,
            releaseYear: item.releaseYear,
            totalEpisodes: max(item.totalEpisodes, 1),
            totalSeasons: max(item.totalSeasons, 1),
            episodeDurationMinutes: max(item.durationMinutes, 24),
            directorName: genericDirectors.contains(item.director) ? nil : item.director.nilIfEmpty,
            studioName: item.studio.nilIfEmpty,
            snapshotData: try? JSONEncoder().encode(item)
        )
        modelContext.insert(created)
        saveChanges()
        return created
    }

    public func setStatus(_ status: WatchTrackingStatus?, for item: MediaItem) {
        let record = upsert(from: item)
        applyStatus(status, to: record)
    }

    public func setStatus(_ status: WatchTrackingStatus?, mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        applyStatus(status, to: record)
    }

    @discardableResult
    public func toggleFavorite(for item: MediaItem) -> Bool {
        let record = upsert(from: item)
        record.isFavorite.toggle()
        record.updatedAt = Date()
        saveChanges()
        return record.isFavorite
    }

    @discardableResult
    public func toggleWatchlist(for item: MediaItem) -> Bool {
        let record = upsert(from: item)
        record.inWatchlist.toggle()
        if record.inWatchlist && record.status == nil {
            record.status = .planning
        }
        record.updatedAt = Date()
        saveChanges()
        return record.inWatchlist
    }

    public func setPersonalRating(_ rating: Double?, for item: MediaItem) {
        let record = upsert(from: item)
        record.personalRating = rating
        record.updatedAt = Date()
        saveChanges()
    }

    public func setPersonalRating(_ rating: Double?, mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        record.personalRating = rating
        record.updatedAt = Date()
        saveChanges()
    }

    public func setNotes(_ notes: String, for item: MediaItem) {
        let record = upsert(from: item)
        record.notes = notes
        record.updatedAt = Date()
        saveChanges()
    }

    public func setAlertsEnabled(_ enabled: Bool, mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        record.alertsEnabled = enabled
        record.updatedAt = Date()
        saveChanges()
    }

    public func savePlaybackPreferences(
        mediaID: String,
        sourceID: String?,
        audioLang: String?,
        subtitleLang: String?,
        quality: VideoQualityTier?
    ) {
        guard let record = entry(for: mediaID) else { return }
        record.preferredSourceID = sourceID
        record.preferredAudioLanguage = audioLang
        record.preferredSubtitleLanguage = subtitleLang
        record.preferredQuality = quality
        record.updatedAt = Date()
        saveChanges()
    }

    public func savePreferredPlaybackRate(_ rate: Float, mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        record.preferredPlaybackRate = rate
        record.updatedAt = Date()
        saveChanges()
    }

    public func incrementRewatchCount(mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        record.rewatchCount += 1
        record.finishDate = Date()
        record.updatedAt = Date()
        saveChanges()
    }

    public func favorites() -> [MediaItem] {
        let descriptor = FetchDescriptor<LibraryEntryRecord>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(mediaItemFallback(from:))
    }

    public func deleteEntry(mediaID: String) {
        guard let record = entry(for: mediaID) else { return }
        modelContext.delete(record)
        saveChanges()
    }

    public func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            CVLogger.database.error("Library save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyStatus(_ status: WatchTrackingStatus?, to record: LibraryEntryRecord) {
        let previous = record.status
        record.status = status
        if status == .watching && record.startDate == nil {
            record.startDate = Date()
        } else if status == .completed {
            if record.startDate == nil { record.startDate = Date() }
            if record.finishDate == nil { record.finishDate = Date() }
            if previous == .rewatching {
                record.rewatchCount += 1
            }
        }
        record.updatedAt = Date()
        saveChanges()
    }

    private func mediaItemFallback(from record: LibraryEntryRecord) -> MediaItem {
        if let snap = record.snapshot {
            return snap
        }
        return MediaItem(
            id: record.mediaID,
            primarySource: MediaReference(id: record.mediaID)?.provider ?? .openCinema,
            projectType: record.projectType,
            localizedTitle: record.title,
            originalTitle: record.originalTitle,
            synopsis: record.notes,
            releaseYear: record.releaseYear,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: record.genres,
            durationMinutes: record.episodeDurationMinutes,
            totalSeasons: record.totalSeasons,
            totalEpisodes: record.totalEpisodes,
            ratings: MultiSourceRatings(),
            posterURL: record.posterURL,
            backdropURL: record.backdropURL
        )
    }
}
