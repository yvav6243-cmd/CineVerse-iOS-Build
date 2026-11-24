import Foundation
import SwiftData

public enum BackupError: LocalizedError, Sendable {
    case incompatibleSchema(Int)
    case corruptedFile(String)

    public var errorDescription: String? {
        switch self {
        case .incompatibleSchema(let version):
            return "Backup file uses unsupported schema version \(version)."
        case .corruptedFile(let reason):
            return "Could not read backup file: \(reason)"
        }
    }
}

@MainActor
public enum BackupService {
    public static func exportJSON(from modelContext: ModelContext, settings: SettingsStore) throws -> Data {
        let entries = ((try? modelContext.fetch(FetchDescriptor<LibraryEntryRecord>())) ?? []).map { $0.toDTO() }
        let progress = ((try? modelContext.fetch(FetchDescriptor<PlaybackProgressRecord>())) ?? []).map { $0.toDTO() }
        let history = ((try? modelContext.fetch(FetchDescriptor<WatchHistoryRecord>())) ?? []).map { $0.toDTO() }
        let collections = ((try? modelContext.fetch(FetchDescriptor<CustomCollectionRecord>())) ?? []).map { $0.toDTO() }
        let sources = ((try? modelContext.fetch(FetchDescriptor<UserVideoSourceRecord>())) ?? []).map { $0.toDTO() }
        let searchHistory = ((try? modelContext.fetch(FetchDescriptor<SearchHistoryRecord>())) ?? []).map { $0.toDTO() }

        let backup = CineVerseBackup(
            schemaVersion: CineVerseBackup.currentSchemaVersion,
            exportedAt: Date(),
            entries: entries,
            progress: progress,
            history: history,
            collections: collections,
            sources: sources,
            preferences: settings.exportDTO(),
            searchHistory: searchHistory
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    public static func decodeBackup(from data: Data) throws -> CineVerseBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: CineVerseBackup
        do {
            backup = try decoder.decode(CineVerseBackup.self, from: data)
        } catch {
            throw BackupError.corruptedFile(error.localizedDescription)
        }

        guard backup.schemaVersion <= CineVerseBackup.currentSchemaVersion else {
            throw BackupError.incompatibleSchema(backup.schemaVersion)
        }
        return backup
    }

    public static func importBackup(
        data: Data,
        mode: BackupImportMode,
        into modelContext: ModelContext,
        settings: SettingsStore
    ) throws -> BackupImportReport {
        let backup = try decodeBackup(from: data)

        if mode == .replace {
            try clearExistingData(in: modelContext)
        }

        var entriesImported = 0
        for dto in backup.entries {
            if let existing = fetchEntry(mediaID: dto.mediaID, in: modelContext) {
                if dto.updatedAt > existing.updatedAt || mode == .replace {
                    apply(dto, to: existing)
                    entriesImported += 1
                }
            } else {
                let record = LibraryEntryRecord(
                    mediaID: dto.mediaID,
                    title: dto.title,
                    originalTitle: dto.originalTitle,
                    projectTypeRaw: dto.projectTypeRaw,
                    posterURLString: dto.posterURLString,
                    backdropURLString: dto.backdropURLString,
                    genres: dto.genres,
                    releaseYear: dto.releaseYear,
                    statusRaw: dto.statusRaw,
                    isFavorite: dto.isFavorite,
                    inWatchlist: dto.inWatchlist,
                    personalRating: dto.personalRating,
                    notes: dto.notes,
                    startDate: dto.startDate,
                    finishDate: dto.finishDate,
                    addedAt: dto.addedAt,
                    updatedAt: dto.updatedAt,
                    totalEpisodes: dto.totalEpisodes,
                    totalSeasons: dto.totalSeasons,
                    episodeDurationMinutes: dto.episodeDurationMinutes,
                    rewatchCount: dto.rewatchCount,
                    alertsEnabled: dto.alertsEnabled,
                    preferredSourceID: dto.preferredSourceID,
                    preferredAudioLanguage: dto.preferredAudioLanguage,
                    preferredSubtitleLanguage: dto.preferredSubtitleLanguage,
                    preferredQualityRaw: dto.preferredQualityRaw
                )
                modelContext.insert(record)
                entriesImported += 1
            }
        }

        var progressImported = 0
        for dto in backup.progress {
            if let existing = fetchProgress(key: dto.key, in: modelContext) {
                if dto.lastUpdated > existing.lastUpdated || mode == .replace {
                    existing.positionSeconds = dto.positionSeconds
                    existing.durationSeconds = dto.durationSeconds
                    existing.isWatched = dto.isWatched
                    existing.watchedAt = dto.watchedAt
                    existing.lastUpdated = dto.lastUpdated
                    existing.sourceID = dto.sourceID
                    progressImported += 1
                }
            } else {
                let record = PlaybackProgressRecord(
                    mediaID: dto.mediaID,
                    season: dto.season,
                    episode: dto.episode,
                    episodeTitle: dto.episodeTitle,
                    positionSeconds: dto.positionSeconds,
                    durationSeconds: dto.durationSeconds,
                    isWatched: dto.isWatched,
                    watchedAt: dto.watchedAt,
                    lastUpdated: dto.lastUpdated,
                    sourceID: dto.sourceID
                )
                modelContext.insert(record)
                progressImported += 1
            }
        }

        let existingHistoryIDs = Set(
            ((try? modelContext.fetch(FetchDescriptor<WatchHistoryRecord>())) ?? []).map(\.id)
        )
        var historyImported = 0
        for dto in backup.history where !existingHistoryIDs.contains(dto.id) {
            let record = WatchHistoryRecord(
                id: dto.id,
                mediaID: dto.mediaID,
                title: dto.title,
                projectTypeRaw: dto.projectTypeRaw,
                genres: dto.genres,
                season: dto.season,
                episode: dto.episode,
                minutesWatched: dto.minutesWatched,
                watchedAt: dto.watchedAt
            )
            modelContext.insert(record)
            historyImported += 1
        }

        var collectionsImported = 0
        for dto in backup.collections {
            let existing = fetchCollection(id: dto.id, in: modelContext)
            let collection = existing ?? CustomCollectionRecord(
                id: dto.id,
                name: dto.name,
                symbolName: dto.symbolName,
                createdAt: dto.createdAt,
                sortOrder: dto.sortOrder
            )
            if existing == nil {
                modelContext.insert(collection)
            }
            for itemDTO in dto.items {
                if !collection.items.contains(where: { $0.mediaID == itemDTO.mediaID }) {
                    let itemRecord = CollectionItemRecord(
                        mediaID: itemDTO.mediaID,
                        title: itemDTO.title,
                        posterURLString: itemDTO.posterURLString,
                        projectTypeRaw: itemDTO.projectTypeRaw,
                        releaseYear: itemDTO.releaseYear,
                        rating: itemDTO.rating,
                        addedAt: itemDTO.addedAt,
                        position: itemDTO.position,
                        collection: collection
                    )
                    modelContext.insert(itemRecord)
                    collection.items.append(itemRecord)
                }
            }
            collectionsImported += 1
        }

        var directSourcesImported = 0
        var skippedLocalFiles: [String] = []
        let existingSourceIDs = Set(
            ((try? modelContext.fetch(FetchDescriptor<UserVideoSourceRecord>())) ?? []).map(\.id)
        )
        for dto in backup.sources {
            if dto.kindRaw == UserVideoSourceKind.localFile.rawValue || !dto.isRestorable {
                skippedLocalFiles.append(dto.label)
                continue
            }
            guard !existingSourceIDs.contains(dto.id),
                  let urlStr = dto.urlString,
                  case .success = SourceURLValidator.validateSyntax(urlStr) else {
                continue
            }
            let record = UserVideoSourceRecord(
                id: dto.id,
                mediaID: dto.mediaID,
                season: dto.season,
                episode: dto.episode,
                kind: .directLink,
                urlString: urlStr,
                label: dto.label,
                subtitles: dto.subtitles,
                addedAt: dto.addedAt
            )
            modelContext.insert(record)
            directSourcesImported += 1
        }

        for dto in backup.searchHistory {
            let normalized = dto.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let existing = (try? modelContext.fetch(
                FetchDescriptor<SearchHistoryRecord>(predicate: #Predicate { $0.normalizedQuery == normalized })
            ))?.first
            if existing == nil {
                modelContext.insert(SearchHistoryRecord(query: dto.query, searchedAt: dto.searchedAt))
            }
        }

        if let prefs = backup.preferences {
            settings.applyDTO(prefs)
        }

        try modelContext.save()

        return BackupImportReport(
            entriesImported: entriesImported,
            progressImported: progressImported,
            historyImported: historyImported,
            collectionsImported: collectionsImported,
            directSourcesImported: directSourcesImported,
            skippedLocalFiles: skippedLocalFiles
        )
    }

    private static func clearExistingData(in context: ModelContext) throws {
        for item in ((try? context.fetch(FetchDescriptor<LibraryEntryRecord>())) ?? []) { context.delete(item) }
        for item in ((try? context.fetch(FetchDescriptor<PlaybackProgressRecord>())) ?? []) { context.delete(item) }
        for item in ((try? context.fetch(FetchDescriptor<WatchHistoryRecord>())) ?? []) { context.delete(item) }
        for item in ((try? context.fetch(FetchDescriptor<CustomCollectionRecord>())) ?? []) { context.delete(item) }
        for item in ((try? context.fetch(FetchDescriptor<UserVideoSourceRecord>())) ?? []) { context.delete(item) }
        for item in ((try? context.fetch(FetchDescriptor<SearchHistoryRecord>())) ?? []) { context.delete(item) }
        try context.save()
    }

    private static func fetchEntry(mediaID: String, in context: ModelContext) -> LibraryEntryRecord? {
        try? context.fetch(FetchDescriptor<LibraryEntryRecord>(predicate: #Predicate { $0.mediaID == mediaID })).first
    }

    private static func fetchProgress(key: String, in context: ModelContext) -> PlaybackProgressRecord? {
        try? context.fetch(FetchDescriptor<PlaybackProgressRecord>(predicate: #Predicate { $0.key == key })).first
    }

    private static func fetchCollection(id: UUID, in context: ModelContext) -> CustomCollectionRecord? {
        try? context.fetch(FetchDescriptor<CustomCollectionRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private static func apply(_ dto: LibraryEntryDTO, to record: LibraryEntryRecord) {
        record.title = dto.title
        record.originalTitle = dto.originalTitle
        record.projectTypeRaw = dto.projectTypeRaw
        record.posterURLString = dto.posterURLString
        record.backdropURLString = dto.backdropURLString
        record.genres = dto.genres
        record.releaseYear = dto.releaseYear
        record.statusRaw = dto.statusRaw
        record.isFavorite = dto.isFavorite
        record.inWatchlist = dto.inWatchlist
        record.personalRating = dto.personalRating
        record.notes = dto.notes
        record.startDate = dto.startDate
        record.finishDate = dto.finishDate
        record.updatedAt = dto.updatedAt
        record.totalEpisodes = dto.totalEpisodes
        record.totalSeasons = dto.totalSeasons
        record.episodeDurationMinutes = dto.episodeDurationMinutes
        record.rewatchCount = dto.rewatchCount
        record.alertsEnabled = dto.alertsEnabled
        record.preferredSourceID = dto.preferredSourceID
        record.preferredAudioLanguage = dto.preferredAudioLanguage
        record.preferredSubtitleLanguage = dto.preferredSubtitleLanguage
        record.preferredQualityRaw = dto.preferredQualityRaw
    }
}
