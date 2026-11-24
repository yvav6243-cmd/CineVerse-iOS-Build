import Foundation
import SwiftData
import Testing
@testable import CineVerse

@Suite("Backup Service")
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

        // Restore into a fresh in-memory container
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
}
