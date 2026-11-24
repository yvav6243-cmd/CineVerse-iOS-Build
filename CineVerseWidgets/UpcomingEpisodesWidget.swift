import SwiftUI
import WidgetKit

struct UpcomingEpisodesEntry: TimelineEntry {
    let date: Date
    let items: [WidgetUpcomingItem]
}

struct UpcomingEpisodesProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEpisodesEntry {
        UpcomingEpisodesEntry(
            date: Date(),
            items: [
                WidgetUpcomingItem(
                    id: "placeholder-1",
                    title: "Upcoming Episode",
                    episodeLabel: "S1 E1",
                    airDate: Date().addingTimeInterval(3600),
                    deepLinkURLString: "cineverse://calendar"
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEpisodesEntry) -> Void) {
        let snapshot = WidgetSnapshotLoader.load()
        completion(UpcomingEpisodesEntry(date: snapshot.updatedAt, items: snapshot.upcoming))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEpisodesEntry>) -> Void) {
        let snapshot = WidgetSnapshotLoader.load()
        let entry = UpcomingEpisodesEntry(date: Date(), items: snapshot.upcoming)
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

public struct UpcomingEpisodesWidget: Widget {
    public let kind: String = "UpcomingEpisodesWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingEpisodesProvider()) { entry in
            UpcomingEpisodesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Episodes")
        .description("See upcoming episodes and premieres from your tracked list and schedule.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct UpcomingEpisodesWidgetView: View {
    let entry: UpcomingEpisodesEntry

    @Environment(\.widgetFamily) private var family

    private let irisColor = Color(red: 110 / 255, green: 91 / 255, blue: 1.0)

    private var visibleCount: Int {
        family == .systemLarge ? 5 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Upcoming Schedule", systemImage: "calendar.badge.clock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(irisColor)
                Spacer()
            }

            if entry.items.isEmpty {
                emptyState
            } else {
                ForEach(entry.items.prefix(visibleCount)) { item in
                    if let url = URL(string: item.deepLinkURLString) {
                        Link(destination: url) {
                            upcomingRow(item)
                        }
                    } else {
                        upcomingRow(item)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "cineverse://calendar"))
    }

    private func upcomingRow(_ item: WidgetUpcomingItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.episodeLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(irisColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(formattedAirDate(item.airDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(irisColor)
            Text("No Upcoming Airings")
                .font(.caption.weight(.semibold))
            Text("Open Premiere Calendar in CineVerse to sync upcoming episodes.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedAirDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
