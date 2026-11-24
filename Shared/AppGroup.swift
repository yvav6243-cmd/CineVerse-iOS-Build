import Foundation

public enum AppGroup {
    public static var identifier: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "CVAppGroup") as? String,
           !configured.isEmpty,
           !configured.hasPrefix("$(") {
            return configured
        }
        return "group.com.cineverse.app"
    }

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var snapshotURL: URL? {
        containerURL?.appendingPathComponent("widget_snapshot.json")
    }

    public static var thumbnailsDirectoryURL: URL? {
        guard let dir = containerURL?.appendingPathComponent("WidgetThumbnails", isDirectory: true) else {
            return nil
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
