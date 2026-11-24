import Foundation
import UserNotifications

@MainActor
public final class EpisodeAlertScheduler {
    private let center = UNUserNotificationCenter.current()
    private let libraryRepository: LibraryRepositoryProtocol
    private let detailsRepository: DetailsRepositoryProtocol
    private let settingsStore: SettingsStore

    public init(
        libraryRepository: LibraryRepositoryProtocol,
        detailsRepository: DetailsRepositoryProtocol,
        settingsStore: SettingsStore
    ) {
        self.libraryRepository = libraryRepository
        self.detailsRepository = detailsRepository
        self.settingsStore = settingsStore
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            CVLogger.notifications.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func syncScheduledAlerts() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let allEntries = libraryRepository.allEntries()
        let tracked = allEntries.filter { entry in
            let activeStatus = entry.status == .watching || entry.status == .planning || entry.status == .rewatching
            let wantsAlerts = entry.alertsEnabled || settingsStore.episodeAlertsEnabled
            return activeStatus && wantsAlerts && entry.projectType.isEpisodic
        }

        let pending = await center.pendingNotificationRequests()
        let cineVersePendingIDs = pending.map(\.identifier).filter { $0.hasPrefix("episode-") }
        center.removePendingNotificationRequests(withIdentifiers: cineVersePendingIDs)

        guard !tracked.isEmpty else { return }

        var scheduledCount = 0
        for entry in tracked.prefix(30) {
            guard scheduledCount < 60,
                  let ref = MediaReference(id: entry.mediaID) else { continue }

            let details = try? await detailsRepository.details(
                for: ref,
                language: settingsStore.contentLanguageCode,
                watchRegion: settingsStore.watchRegion,
                offlineSnapshot: entry.snapshot
            )

            guard let airDate = details?.nextAiringDate, airDate > Date() else { continue }

            let episodeNum = details?.nextAiringEpisodeNumber ?? 1
            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = "Episode \(episodeNum) airs today."
            content.sound = .default
            content.userInfo = ["deepLink": "cineverse://media/\(entry.mediaID)"]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: airDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "episode-\(entry.mediaID)-\(episodeNum)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                scheduledCount += 1
            } catch {
                CVLogger.notifications.error("Failed scheduling alert: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    public func clearAllScheduledAlerts() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("episode-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
