import Foundation
import Observation

public enum PremiereCalendarScope: String, CaseIterable, Identifiable, Sendable {
    case allUpcoming = "All Upcoming"
    case myList = "My List"

    public var id: String { rawValue }
}

@MainActor
@Observable
public final class PremiereCalendarViewModel {
    private let container: AppContainer

    public var loadState: LoadState<[PremiereEvent]> = .idle
    public var scope: PremiereCalendarScope = .allUpcoming
    public var selectedCategory: MediaProjectType? = nil
    public var selectedDay: Date? = nil
    public var trackedAlertsByMediaID: [String: Bool] = [:]
    public var notificationDeniedAlert: Bool = false

    public let daysWindow: [Date]

    public init(container: AppContainer) {
        self.container = container
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        self.daysWindow = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    public func reloadTrackedEntries() {
        let entries = container.libraryRepository.allEntries()
        var map: [String: Bool] = [:]
        for entry in entries {
            map[entry.mediaID] = entry.alertsEnabled
        }
        trackedAlertsByMediaID = map
    }

    public func loadEvents() async {
        reloadTrackedEntries()
        if case .idle = loadState {
            loadState = .loading
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let week2Start = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let week1End = week2Start.addingTimeInterval(-1)
        let week2End = (calendar.date(byAdding: .day, value: 14, to: start) ?? start).addingTimeInterval(-1)

        let region = container.settingsStore.watchRegion
        let language = container.settingsStore.contentLanguageCode
        let repo = container.calendarRepository

        do {
            async let firstWeek = repo.upcomingEvents(
                from: start,
                to: week1End,
                watchRegion: region,
                language: language
            )
            async let secondWeek = repo.upcomingEvents(
                from: week2Start,
                to: week2End,
                watchRegion: region,
                language: language
            )

            let combined = try await firstWeek + secondWeek
            var seen: Set<String> = []
            let unique = combined
                .filter { seen.insert($0.id).inserted }
                .sorted { $0.date < $1.date }
            loadState = .loaded(unique)
        } catch {
            if let existing = loadState.value, !existing.isEmpty {
                return
            }
            loadState = .failed(error.localizedDescription)
        }
    }

    public var filteredEvents: [PremiereEvent] {
        guard let events = loadState.value else { return [] }
        let calendar = Calendar.current
        return events.filter { event in
            if scope == .myList, trackedAlertsByMediaID[event.mediaReference.id] == nil {
                return false
            }
            if let category = selectedCategory, event.kind != category {
                return false
            }
            if let selectedDay, !calendar.isDate(event.date, inSameDayAs: selectedDay) {
                return false
            }
            return true
        }
    }

    public var groupedSections: [(day: Date, events: [PremiereEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { (day: $0.key, events: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day < $1.day }
    }

    public func availableCategories() -> [MediaProjectType] {
        guard let events = loadState.value else { return [] }
        let present = Set(events.map(\.kind))
        return MediaProjectType.allCases.filter { present.contains($0) }
    }

    public func isTracked(_ mediaID: String) -> Bool {
        trackedAlertsByMediaID[mediaID] != nil
    }

    public func alertsEnabled(for mediaID: String) -> Bool {
        trackedAlertsByMediaID[mediaID] ?? false
    }

    public func toggleAlert(for event: PremiereEvent) async {
        let mediaID = event.mediaReference.id
        guard let currentlyEnabled = trackedAlertsByMediaID[mediaID] else { return }

        let nextEnabled = !currentlyEnabled
        if nextEnabled {
            let granted = await container.alertScheduler.requestAuthorization()
            guard granted else {
                notificationDeniedAlert = true
                return
            }
        }

        container.libraryRepository.setAlertsEnabled(nextEnabled, mediaID: mediaID)
        trackedAlertsByMediaID[mediaID] = nextEnabled
        Haptics.selection()
        await container.alertScheduler.syncScheduledAlerts()
    }
}
