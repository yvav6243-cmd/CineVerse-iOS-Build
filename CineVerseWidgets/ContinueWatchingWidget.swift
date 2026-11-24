import SwiftUI
import WidgetKit
import UIKit

enum WidgetSnapshotLoader {
    static func load() -> WidgetSnapshot {
        guard let url = AppGroup.snapshotURL,
              let data = try? Data(contentsOf: url) else {
            return WidgetSnapshot()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? WidgetSnapshot()
    }

    static func thumbnailImage(named fileName: String?) -> UIImage? {
        guard let fileName,
              let dir = AppGroup.thumbnailsDirectoryURL else {
            return nil
        }
        let fileURL = dir.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }
}

struct ContinueWatchingEntry: TimelineEntry {
    let date: Date
    let items: [WidgetContinueItem]
}

struct ContinueWatchingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueWatchingEntry {
        ContinueWatchingEntry(
            date: Date(),
            items: [
                WidgetContinueItem(
                    id: "placeholder-1",
                    title: "Continue Watching",
                    subtitle: "S1 E1 · 24m left",
                    progressFraction: 0.45,
                    deepLinkURLString: "cineverse://tab/home"
                )
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueWatchingEntry) -> Void) {
        let snapshot = WidgetSnapshotLoader.load()
        completion(ContinueWatchingEntry(date: snapshot.updatedAt, items: snapshot.continueWatching))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueWatchingEntry>) -> Void) {
        let snapshot = WidgetSnapshotLoader.load()
        let entry = ContinueWatchingEntry(date: Date(), items: snapshot.continueWatching)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

public struct ContinueWatchingWidget: Widget {
    public let kind: String = "ContinueWatchingWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContinueWatchingProvider()) { entry in
            ContinueWatchingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Continue Watching")
        .description("Pick up your movies, series, and anime right where you left off.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ContinueWatchingWidgetView: View {
    let entry: ContinueWatchingEntry

    @Environment(\.widgetFamily) private var family

    private let irisColor = Color(red: 110 / 255, green: 91 / 255, blue: 1.0)

    var body: some View {
        Group {
            if entry.items.isEmpty {
                emptyState
            } else if family == .systemSmall, let firstItem = entry.items.first {
                smallLayout(item: firstItem)
            } else {
                mediumLayout
            }
        }
        .widgetURL(primaryDeepLink)
    }

    private var primaryDeepLink: URL? {
        if let first = entry.items.first, let url = URL(string: first.deepLinkURLString) {
            return url
        }
        return URL(string: "cineverse://tab/home")
    }

    private func smallLayout(item: WidgetContinueItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                thumbnailView(fileName: item.thumbnailFileName, size: CGSize(width: 42, height: 60))

                VStack(alignment: .leading, spacing: 3) {
                    Text("RESUME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(irisColor)

                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 2)

            Text(item.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(value: min(max(item.progressFraction, 0), 1))
                .tint(irisColor)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Continue Watching", systemImage: "play.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(irisColor)
                Spacer()
            }

            ForEach(entry.items.prefix(2)) { item in
                if let url = URL(string: item.deepLinkURLString) {
                    Link(destination: url) {
                        mediumItemRow(item)
                    }
                } else {
                    mediumItemRow(item)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func mediumItemRow(_ item: WidgetContinueItem) -> some View {
        HStack(spacing: 10) {
            thumbnailView(fileName: item.thumbnailFileName, size: CGSize(width: 34, height: 48))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: min(max(item.progressFraction, 0), 1))
                    .tint(irisColor)
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(fileName: String?, size: CGSize) -> some View {
        if let image = WidgetSnapshotLoader.thumbnailImage(named: fileName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "film")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "play.tv")
                .font(.title2)
                .foregroundStyle(irisColor)
            Text("Nothing in Progress")
                .font(.caption.weight(.semibold))
            Text("Start watching in CineVerse to track progress here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
