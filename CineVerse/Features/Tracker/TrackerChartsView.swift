import SwiftUI
import Charts

public struct TrackerChartsView: View {
    let snapshot: TrackerAnalyticsSnapshot
    let dailyActivity: [DailyWatchActivityPoint]
    var onSelectStatus: ((WatchTrackingStatus) -> Void)?

    public init(
        snapshot: TrackerAnalyticsSnapshot,
        dailyActivity: [DailyWatchActivityPoint],
        onSelectStatus: ((WatchTrackingStatus) -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.dailyActivity = dailyActivity
        self.onSelectStatus = onSelectStatus
    }

    public var body: some View {
        VStack(spacing: CVSpacing.md) {
            statusBreakdownCard
            monthlyHoursCard
            dailyMinutesCard
            topGenresCard
            categoryBreakdownCard
        }
    }

    private var statusBreakdownCard: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            chartTitle("Status Breakdown", symbolName: "checklist")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 135), spacing: CVSpacing.xs)],
                spacing: CVSpacing.xs
            ) {
                ForEach(WatchTrackingStatus.allCases) { status in
                    let count = snapshot.statusBreakdown[status] ?? 0
                    let chipContent = HStack(spacing: 6) {
                        Image(systemName: status.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: status.accentHex))
                        Text(LocalizedStringKey(status.rawValue))
                            .font(CVFont.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(count)")
                            .font(CVFont.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: status.accentHex))
                    }
                    .padding(.horizontal, CVSpacing.sm)
                    .padding(.vertical, 8)
                    .background(
                        Color(hex: status.accentHex).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: CVRadius.chip, style: .continuous)
                    )

                    if let onSelectStatus {
                        Button {
                            Haptics.selection()
                            onSelectStatus(status)
                        } label: {
                            chipContent
                        }
                        .buttonStyle(.plain)
                    } else {
                        chipContent
                    }
                }
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var monthlyHoursCard: some View {
        let maxHours = max(snapshot.monthlyActivity.map(\.hoursWatched).max() ?? 0, 1.0)

        return VStack(alignment: .leading, spacing: CVSpacing.sm) {
            chartTitle("Monthly Watch Hours", symbolName: "chart.bar.fill")

            if snapshot.monthlyActivity.allSatisfy({ $0.hoursWatched <= 0 }) {
                emptyChartMessage("Complete episodes or movies to populate your 12-month activity.")
            } else {
                Chart(snapshot.monthlyActivity) { point in
                    BarMark(
                        x: .value("Month", point.monthLabel),
                        y: .value("Hours", point.hoursWatched)
                    )
                    .foregroundStyle(CVColor.iris.gradient)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...(maxHours * 1.15))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var dailyMinutesCard: some View {
        let maxMinutes = max(dailyActivity.map(\.minutesWatched).max() ?? 0, 30)

        return VStack(alignment: .leading, spacing: CVSpacing.sm) {
            chartTitle("Last 30 Days (Minutes)", symbolName: "waveform.path.ecg")

            if dailyActivity.allSatisfy({ $0.minutesWatched == 0 }) {
                emptyChartMessage("No watch sessions logged in the past 30 days.")
            } else {
                Chart(dailyActivity) { point in
                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Minutes", point.minutesWatched)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CVColor.iris.opacity(0.35), CVColor.iris.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Minutes", point.minutesWatched)
                    )
                    .foregroundStyle(CVColor.iris)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...Int(Double(maxMinutes) * 1.15))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var topGenresCard: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            chartTitle("Top Genres", symbolName: "chart.pie.fill")

            if snapshot.topGenres.isEmpty {
                emptyChartMessage("Add titles to your tracker to analyze favorite genres.")
            } else {
                HStack(spacing: CVSpacing.md) {
                    Chart(snapshot.topGenres) { point in
                        SectorMark(
                            angle: .value("Projects", max(point.projectCount, 1)),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Genre", point.genre))
                    }
                    .chartLegend(.hidden)
                    .frame(width: 148, height: 148)
                    .overlay {
                        if let lead = snapshot.topGenres.first {
                            VStack(spacing: 2) {
                                Text(lead.genre)
                                    .font(CVFont.micro)
                                    .lineLimit(1)
                                Text("\(lead.projectCount)")
                                    .font(CVFont.cardTitle)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: 74)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(snapshot.topGenres.prefix(5).enumerated()), id: \.element.id) { index, point in
                            HStack(spacing: 6) {
                                Text("\(index + 1).")
                                    .font(CVFont.micro)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                                Text(point.genre)
                                    .font(CVFont.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(point.projectCount)")
                                    .font(CVFont.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            chartTitle("Category Breakdown", symbolName: "square.grid.2x2.fill")

            if snapshot.categoryBreakdown.isEmpty {
                emptyChartMessage("Start watching or completing projects to see category distribution.")
            } else {
                Chart(snapshot.categoryBreakdown) { point in
                    BarMark(
                        x: .value("Projects", point.count),
                        y: .value("Category", point.category.displayName)
                    )
                    .foregroundStyle(CVColor.iris.gradient)
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text("\(point.count)")
                            .font(CVFont.micro)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: max(CGFloat(snapshot.categoryBreakdown.count) * 34, 96))
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private func chartTitle(_ title: String, symbolName: String) -> some View {
        HStack(spacing: CVSpacing.xs) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CVColor.iris)
            Text(title)
                .font(CVFont.cardTitle)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func emptyChartMessage(_ message: String) -> some View {
        Text(message)
            .font(CVFont.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
            .multilineTextAlignment(.center)
    }
}
