import Foundation
import SwiftData
import Testing
@testable import CineVerse

@Suite("Category 10B: Backup, Merge Restore & Settings Persistence")
struct BackupServiceTests {
    @MainActor
    @Test func roundtripPreservesLibraryProgressCollectionsAndFlagsLocalSources() throws {
        let sourceContainer = try PersistenceController.makeContainer(inMemory: true)
        let sourceContext = sourceContainer.mainContext
        let sourceSettings = SettingsStore(modelContext: sourceContext)
        sourceSettings.profileName = "Alex"

        let libRepo = LibraryRepository(modelContext: sourceContext)
        let item = MediaItem(
            id: "tmdb:movie:157336",
            primarySource: .tmdb,
            projectType: .movie,
            localizedTitle: "Interstellar",
            originalTitle: "Interstellar",
            synopsis: "Space exploration",
            releaseYear: 2014,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: ["Sci-Fi"],
            durationMinutes: 169,
            ratings: MultiSourceRatings(tmdbScore: 8.4)
        )
        libRepo.setStatus(.completed, for: item)
        libRepo.setPersonalRating(9.5, for: item)

        let colRepo = CollectionsRepository(modelContext: sourceContext)
        let col = colRepo.createCollection(name: "Must Watch", symbolName: "star.fill")
        colRepo.add(item: item, to: col.id)

        sourceContext.insert(UserVideoSourceRecord(
            mediaID: item.id,
            kind: .directLink,
            urlString: "https://cdn.example.com/movie.m3u8",
            label: "Primary HLS"
        ))
        sourceContext.insert(UserVideoSourceRecord(
            mediaID: item.id,
            kind: .localFile,
            relativeFilePath: "Videos/local.mp4",
            label: "local.mp4"
        ))
        try sourceContext.save()

        let exportedData = try BackupService.exportJSON(from: sourceContext, settings: sourceSettings)

        let destContainer = try PersistenceController.makeContainer(inMemory: true)
        let destContext = destContainer.mainContext
        let destSettings = SettingsStore(modelContext: destContext)

        let report = try BackupService.importBackup(
            data: exportedData,
            mode: .replace,
            into: destContext,
            settings: destSettings
        )

        #expect(report.entriesImported == 1)
        #expect(report.collectionsImported == 1)
        #expect(report.directSourcesImported == 1)
        #expect(report.skippedLocalFiles == ["local.mp4"])
        #expect(destSettings.profileName == "Alex")

        let restoredLib = LibraryRepository(modelContext: destContext)
        let restoredEntry = try #require(restoredLib.entry(for: "tmdb:movie:157336"))
        #expect(restoredEntry.status == .completed)
        #expect(restoredEntry.personalRating == 9.5)
    }

    @MainActor
    @Test func mergeImportPreservesExistingDestinationEntriesWhileAddingNewOnes() throws {
        let srcContainer = try PersistenceController.makeContainer(inMemory: true)
        let srcSettings = SettingsStore(modelContext: srcContainer.mainContext)
        let srcLib = LibraryRepository(modelContext: srcContainer.mainContext)
        srcLib.setStatus(.planning, for: MediaItem(
            id: "tmdb:movie:10", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "New Imported", originalTitle: "New Imported", synopsis: "",
            releaseYear: 2025, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama"], durationMinutes: 110, ratings: MultiSourceRatings()
        ))
        let backupData = try BackupService.exportJSON(from: srcContainer.mainContext, settings: srcSettings)

        let destContainer = try PersistenceController.makeContainer(inMemory: true)
        let destSettings = SettingsStore(modelContext: destContainer.mainContext)
        let destLib = LibraryRepository(modelContext: destContainer.mainContext)
        destLib.setStatus(.watching, for: MediaItem(
            id: "anilist:anime:20", primarySource: .aniList, projectType: .anime,
            localizedTitle: "Existing Local", originalTitle: "Existing Local", synopsis: "",
            releaseYear: 2024, countryOfOrigin: "JP", originalLanguage: "ja",
            genres: ["Action"], durationMinutes: 24, ratings: MultiSourceRatings()
        ))

        _ = try BackupService.importBackup(data: backupData, mode: .merge, into: destContainer.mainContext, settings: destSettings)
        #expect(destLib.allEntries().count == 2)
    }

    @MainActor
    @Test func rejectsCorruptedNonJSONBackupData() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let settings = SettingsStore(modelContext: container.mainContext)
        let garbage = Data("not-valid-json".utf8)
        #expect(throws: (any Error).self) {
            _ = try BackupService.importBackup(data: garbage, mode: .merge, into: container.mainContext, settings: settings)
        }
    }

    @MainActor
    @Test func settingsStorePersistsQualitySubtitleStyleAndHomeSectionVisibility() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let settings = SettingsStore(modelContext: container.mainContext)

        settings.defaultQuality = .p1080
        settings.autoplayNext = false
        var style = settings.subtitleStyle
        style.fontSize = 22
        settings.subtitleStyle = style

        let reloaded = SettingsStore(modelContext: container.mainContext)
        #expect(reloaded.defaultQuality == .p1080)
        #expect(reloaded.autoplayNext == false)
        #expect(reloaded.subtitleStyle.fontSize == 22)
        #expect(!reloaded.homeSections.isEmpty)
    }
}
