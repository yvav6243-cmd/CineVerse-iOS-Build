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

    public func enableWatchAvailabilityAlert(for item: MediaItem) async -> Bool {
        _ = libraryRepository.upsert(from: item)
        libraryRepository.setAlertsEnabled(true, mediaID: item.id)
        let granted = await requestAuthorization()
        if granted {
            await syncScheduledAlerts()
        }
        return granted
    }

    public func syncScheduledAlerts() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let allEntries = libraryRepository.allEntries()
        let tracked = allEntries.filter { entry in
            let activeStatus = entry.status == .watching || entry.status == .planning || entry.status == .rewatching || entry.alertsEnabled
            let wantsAlerts = entry.alertsEnabled || settingsStore.episodeAlertsEnabled
            return activeStatus && wantsAlerts
        }

        let pending = await center.pendingNotificationRequests()
        let cineVersePendingIDs = pending.map(\.identifier).filter { $0.hasPrefix("episode-") || $0.hasPrefix("release-") }
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

            if entry.projectType.isEpisodic,
               let airDate = details?.nextAiringDate,
               airDate > Date() {
                let episodeNum = details?.nextAiringEpisodeNumber ?? 1
                let content = UNMutableNotificationContent()
                content.title = entry.title
                content.body = "Episode \(episodeNum) airs today."
                content.sound = .default
                content.userInfo = ["deepLink": "cineverse://media/\(entry.mediaID)"]

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: airDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: "episode-\(entry.mediaID)-\(episodeNum)", content: content, trigger: trigger)
                try? await center.add(request)
                scheduledCount += 1
            } else if entry.alertsEnabled,
                      let releaseDate = details?.releaseDate ?? entry.snapshot?.releaseDate,
                      releaseDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = entry.title
                content.body = "Now released — check CineVerse for streaming or video sources."
                content.sound = .default
                content.userInfo = ["deepLink": "cineverse://media/\(entry.mediaID)"]

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: releaseDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: "release-\(entry.mediaID)", content: content, trigger: trigger)
                try? await center.add(request)
                scheduledCount += 1
            }
        }
    }

    public func clearAllScheduledAlerts() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("episode-") || $0.hasPrefix("release-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
