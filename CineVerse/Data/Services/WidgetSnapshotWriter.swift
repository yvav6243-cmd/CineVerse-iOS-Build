import Foundation
import WidgetKit
import UIKit

@MainActor
public final class WidgetSnapshotWriter {
    private let progressRepository: ProgressRepositoryProtocol
    private let calendarRepository: CalendarRepositoryProtocol
    private let libraryRepository: LibraryRepositoryProtocol
    private let settingsStore: SettingsStore

    public init(
        progressRepository: ProgressRepositoryProtocol,
        calendarRepository: CalendarRepositoryProtocol,
        libraryRepository: LibraryRepositoryProtocol,
        settingsStore: SettingsStore
    ) {
        self.progressRepository = progressRepository
        self.calendarRepository = calendarRepository
        self.libraryRepository = libraryRepository
        self.settingsStore = settingsStore
    }

    public func refreshWidgets() async {
        guard let snapshotURL = AppGroup.snapshotURL else { return }

        let continueItems = progressRepository.continueWatchingItems().prefix(4)
        var continueDTOs: [WidgetContinueItem] = []

        for pair in continueItems {
            let entry = pair.entry
            let prog = pair.progress
            let subtitle: String
            if entry.projectType.isEpisodic {
                subtitle = "S\(prog.season) E\(prog.episode) · \(prog.remainingSeconds.formattedRemainingBrief) left"
            } else {
                subtitle = "\(prog.remainingSeconds.formattedRemainingBrief) left"
            }

            var thumbName: String? = nil
            if let posterURL = entry.posterURL,
               let thumbDir = AppGroup.thumbnailsDirectoryURL,
               let uiImage = await ImagePipeline.shared.image(
                   for: posterURL,
                   targetSize: CGSize(width: 240, height: 300),
                   scale: 1
               ),
               let jpegData = uiImage.jpegData(compressionQuality: 0.78) {
                let sanitized = entry.mediaID.replacingOccurrences(of: ":", with: "_") + ".jpg"
                let fileURL = thumbDir.appendingPathComponent(sanitized)
                try? jpegData.write(to: fileURL, options: .atomic)
                thumbName = sanitized
            }

            continueDTOs.append(
                WidgetContinueItem(
                    id: entry.mediaID,
                    title: entry.title,
                    subtitle: subtitle,
                    progressFraction: prog.fraction,
                    deepLinkURLString: "cineverse://media/\(entry.mediaID)",
                    thumbnailFileName: thumbName
                )
            )
        }

        let trackedIDs = Set(libraryRepository.allEntries().map(\.mediaID))
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let allEvents = (try? await calendarRepository.upcomingEvents(
            from: now,
            to: horizon,
            watchRegion: settingsStore.watchRegion,
            language: settingsStore.contentLanguageCode
        )) ?? []

        let prioritized = allEvents.filter { trackedIDs.contains($0.mediaReference.id) }
        let chosenEvents = (prioritized.isEmpty ? allEvents : prioritized).prefix(5)
        let upcomingDTOs = chosenEvents.map { event in
            WidgetUpcomingItem(
                id: event.id,
                title: event.title,
                episodeLabel: event.formattedEpisodeLabel ?? "Premiere",
                airDate: event.date,
                deepLinkURLString: "cineverse://media/\(event.mediaReference.id)"
            )
        }

        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            continueWatching: continueDTOs,
            upcoming: upcomingDTOs
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: snapshotURL, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
