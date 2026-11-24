import SwiftUI

public struct TrackerView: View {
    let container: AppContainer

    @State private var viewModel: TrackerViewModel
    @State private var editingEntry: LibraryEntryRecord?

    public init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: TrackerViewModel(container: container))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CVSpacing.lg) {
                statsGrid
                    .padding(.horizontal, CVSpacing.md)

                TrackerChartsView(
                    snapshot: viewModel.analytics,
                    dailyActivity: viewModel.dailyActivity,
                    onSelectStatus: { status in
                        withAnimation(CVMotion.snappy) {
                            viewModel.selectedStatus = status
                        }
                    }
                )
                .padding(.horizontal, CVSpacing.md)

                if !viewModel.currentlyWatchingEntries.isEmpty {
                    currentlyWatchingSection
                }

                statusFilteredSection
            }
            .padding(.vertical, CVSpacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tracker")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.history) {
                    Label("Watch History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            TrackerEntryEditorSheet(entry: entry, viewModel: viewModel)
        }
        .onAppear {
            viewModel.reload()
        }
    }

    private var statsGrid: some View {
        let snap = viewModel.analytics
        let avgText = snap.averagePersonalScore > 0
            ? String(format: "%.1f", snap.averagePersonalScore)
            : "—"

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: CVSpacing.sm),
                GridItem(.flexible(), spacing: CVSpacing.sm)
            ],
            spacing: CVSpacing.sm
        ) {
            StatCard(
                title: "Projects",
                value: "\(snap.totalProjectsWatched)",
                subtitle: "\(snap.totalMoviesWatched)M · \(snap.totalSeriesWatched)S · \(snap.totalAnimeWatched)A",
                symbolName: "checkmark.seal.fill",
                accent: CVColor.success
            )
            StatCard(
                title: "Episodes",
                value: "\(snap.totalEpisodesWatched)",
                subtitle: "\(snap.totalSeasonsCompleted) seasons completed",
                symbolName: "tv.fill",
                accent: CVColor.iris
            )
            StatCard(
                title: "Hours",
                value: String(format: "%.1f", snap.totalHoursWatched),
                subtitle: "Total watch time",
                symbolName: "clock.fill",
                accent: CVColor.warning
            )
            StatCard(
                title: "Avg Score",
                value: avgText,
                subtitle: "Personal rating",
                symbolName: "star.fill",
                accent: CVColor.ratingGold
            )
        }
    }

    private var currentlyWatchingSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Currently Watching",
                subtitle: "\(viewModel.currentlyWatchingEntries.count) active projects",
                symbolName: "play.circle.fill",
                actionTitle: nil
            )

            VStack(spacing: CVSpacing.xs) {
                ForEach(viewModel.currentlyWatchingEntries, id: \.mediaID) { entry in
                    currentlyWatchingRow(entry)
                }
            }
            .padding(.horizontal, CVSpacing.md)
        }
    }

    private func currentlyWatchingRow(_ entry: LibraryEntryRecord) -> some View {
        let fraction = viewModel.progressFraction(for: entry)
        let progressText = viewModel.formattedProgress(for: entry)

        return HStack(spacing: CVSpacing.sm) {
            rowPosterAndTitle(entry: entry, subtitle: progressText, progressFraction: fraction)

            Spacer(minLength: 4)

            if entry.projectType.isEpisodic {
                Button {
                    Haptics.impact(.light)
                    viewModel.incrementEpisode(for: entry)
                } label: {
                    Text("+1 Ep")
                }
                .buttonStyle(CVPrimaryButtonStyle(compact: true))
            }

            Button {
                Haptics.selection()
                editingEntry = entry
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(entry.title)")
        }
        .padding(CVSpacing.sm)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var statusFilteredSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Tracked Projects",
                symbolName: "list.bullet.rectangle",
                actionTitle: nil
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    ForEach(WatchTrackingStatus.allCases) { status in
                        let count = viewModel.analytics.statusBreakdown[status] ?? 0
                        let localized = String(localized: String.LocalizationValue(status.rawValue))
                        FilterChip(
                            title: "\(localized) (\(count))",
                            symbolName: status.symbolName,
                            isSelected: viewModel.selectedStatus == status
                        ) {
                            withAnimation(CVMotion.snappy) {
                                viewModel.selectedStatus = status
                            }
                        }
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }

            if viewModel.filteredEntries.isEmpty {
                EmptyStateView(
                    title: "No \(viewModel.selectedStatus.rawValue) Titles",
                    message: "Projects marked as \(viewModel.selectedStatus.rawValue) will show up here.",
                    symbolName: viewModel.selectedStatus.symbolName
                )
                .padding(.vertical, CVSpacing.md)
            } else {
                VStack(spacing: CVSpacing.xs) {
                    ForEach(viewModel.filteredEntries, id: \.mediaID) { entry in
                        trackedRow(entry)
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }

    private func trackedRow(_ entry: LibraryEntryRecord) -> some View {
        let progressText = viewModel.formattedProgress(for: entry)
        let fraction = viewModel.progressFraction(for: entry)

        return HStack(spacing: CVSpacing.sm) {
            rowPosterAndTitle(entry: entry, subtitle: progressText, progressFraction: fraction)

            Spacer(minLength: 4)

            if let rating = entry.personalRating, rating > 0 {
                RatingBadge(score: rating, compact: true)
            }

            Button {
                Haptics.selection()
                editingEntry = entry
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(entry.title)")
        }
        .padding(CVSpacing.sm)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .contextMenu {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit Entry", systemImage: "pencil")
            }

            if entry.projectType.isEpisodic {
                Button {
                    viewModel.incrementEpisode(for: entry)
                } label: {
                    Label("Mark +1 Episode", systemImage: "plus.circle")
                }
            }

            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("Delete from Tracker", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func rowPosterAndTitle(
        entry: LibraryEntryRecord,
        subtitle: String,
        progressFraction: Double
    ) -> some View {
        let content = HStack(spacing: CVSpacing.sm) {
            CachedAsyncImage(
                url: entry.posterURL,
                targetSize: CGSize(width: 54, height: 81),
                fallbackSymbol: entry.projectType.symbolName
            )
            .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.projectType.displayName)
                    Text("•")
                    Text(subtitle)
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                CVProgressBar(
                    fraction: progressFraction,
                    height: 4,
                    trackColor: Color.primary.opacity(0.12)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let ref = entry.resolvedReference {
            NavigationLink(value: Route.details(ref)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
