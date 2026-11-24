import SwiftUI

public struct WatchHistoryView: View {
    let container: AppContainer

    @State private var records: [WatchHistoryRecord] = []

    public init(container: AppContainer) {
        self.container = container
    }

    private var daySections: [(day: Date, items: [WatchHistoryRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.watchedAt) }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.watchedAt > $1.watchedAt }) }
            .sorted { $0.day > $1.day }
    }

    public var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    title: "No Watch History Yet",
                    message: "Episodes and films you play or mark as watched appear here chronologically.",
                    symbolName: "clock.arrow.circlepath"
                )
            } else {
                List {
                    ForEach(daySections, id: \.day) { section in
                        Section(sectionTitle(for: section.day)) {
                            ForEach(section.items, id: \.id) { record in
                                historyRow(record)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Watch History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            records = container.progressRepository.watchHistory(limit: nil)
        }
    }

    @ViewBuilder
    private func historyRow(_ record: WatchHistoryRecord) -> some View {
        if let reference = MediaReference(id: record.mediaID) {
            NavigationLink(value: Route.details(reference)) {
                rowContent(record)
            }
        } else {
            rowContent(record)
        }
    }

    private func rowContent(_ record: WatchHistoryRecord) -> some View {
        HStack(spacing: CVSpacing.sm) {
            Image(systemName: record.projectType.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .frame(width: 34, height: 34)
                .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(record.projectType.displayName)
                    if let episodeLabel = episodeCode(for: record) {
                        Text("•")
                        Text(episodeLabel)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.minutesWatched) min")
                    .font(CVFont.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(record.watchedAt.formatted(date: .omitted, time: .shortened))
                    .font(CVFont.micro)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func episodeCode(for record: WatchHistoryRecord) -> String? {
        guard let episode = record.episode else { return nil }
        if let season = record.season {
            return String(format: "S%d E%d", season, episode)
        }
        return "Ep \(episode)"
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return CineVerseDateFormatters.mediumDisplay.string(from: date)
    }
}
