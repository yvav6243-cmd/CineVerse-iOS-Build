import Foundation
import os

public enum CVLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.cineverse.app"

    public static let network = Logger(subsystem: subsystem, category: "Network")
    public static let database = Logger(subsystem: subsystem, category: "Database")
    public static let player = Logger(subsystem: subsystem, category: "Player")
    public static let sources = Logger(subsystem: subsystem, category: "VideoSources")
    public static let tracker = Logger(subsystem: subsystem, category: "Tracker")
    public static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    public static let app = Logger(subsystem: subsystem, category: "App")
}
