import Foundation
import SwiftData

public enum PersistenceController {
    public static let schema = Schema([
        LibraryEntryRecord.self,
        PlaybackProgressRecord.self,
        WatchHistoryRecord.self,
        CustomCollectionRecord.self,
        CollectionItemRecord.self,
        SearchHistoryRecord.self,
        UserVideoSourceRecord.self,
        AppPreferencesRecord.self
    ])

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func resetLocalStore(fileManager: FileManager = .default) throws {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let storeNames = ["default.store", "default.store-wal", "default.store-shm"]
        for name in storeNames {
            let url = appSupport.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
