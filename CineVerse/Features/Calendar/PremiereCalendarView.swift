import SwiftUI

public struct PremiereCalendarView: View {
    let container: AppContainer

    @State private var viewModel: PremiereCalendarViewModel

    public init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: PremiereCalendarViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerControls
                .background(.bar)

            Divider()

            contentBody
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Premiere Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                categoryMenu
            }
        }
        .alert("Notifications Disabled", isPresented: $viewModel.notificationDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications for CineVerse in iOS Settings to receive upcoming episode alerts.")
        }
        .task {
            await viewModel.loadEvents()
        }
        .onAppear {
            viewModel.reloadTrackedEntries()
        }
    }

    private var headerControls: some View {
        VStack(spacing: CVSpacing.xs) {
            Picker("Scope", selection: $viewModel.scope) {
                ForEach(PremiereCalendarScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, CVSpacing.md)
            .padding(.top, CVSpacing.xs)

            dateStrip
                .padding(.bottom, CVSpacing.xs)
        }
    }

    private var dateStrip: some View {
        let calendar = Calendar.current
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CVSpacing.xs) {
                Button {
                    Haptics.selection()
                    withAnimation(CVMotion.snappy) {
                        viewModel.selectedDay = nil
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("14d")
                            .font(CVFont.micro)
                        Text("All")
                            .font(CVFont.callout.weight(.semibold))
                    }
                    .foregroundStyle(viewModel.selectedDay == nil ? Color.white : Color.primary)
                    .frame(width: 48, height: 54)
                    .background(
                        viewModel.selectedDay == nil ? CVColor.iris : Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                ForEach(viewModel.daysWindow, id: \.self) { day in
                    let isSelected = viewModel.selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                    let weekday = day.formatted(.dateTime.weekday(.abbreviated))
                    let dayNumber = day.formatted(.dateTime.day())

                    Button {
                        Haptics.selection()
                        withAnimation(CVMotion.snappy) {
                            viewModel.selectedDay = isSelected ? nil : day
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(weekday.uppercased())
                                .font(CVFont.micro)
                            Text(dayNumber)
                                .font(CVFont.callout.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(width: 48, height: 54)
                        .background(
                            isSelected ? CVColor.iris : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CVSpacing.md)
        }
    }

    private var categoryMenu: some View {
        Menu {
            Button {
                viewModel.selectedCategory = nil
            } label: {
                if viewModel.selectedCategory == nil {
                    Label("All Categories", systemImage: "checkmark")
                } else {
                    Text("All Categories")
                }
            }
            Divider()
            ForEach(viewModel.availableCategories()) { category in
                Button {
                    viewModel.selectedCategory = category
                } label: {
                    if viewModel.selectedCategory == category {
                        Label(category.pluralTitle, systemImage: "checkmark")
                    } else {
                        Label(category.pluralTitle, systemImage: category.symbolName)
                    }
                }
            }
        } label: {
            Image(
                systemName: viewModel.selectedCategory == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityLabel("Filter by Category")
    }

    @ViewBuilder
    private var contentBody: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            VStack(spacing: CVSpacing.md) {
                ProgressView("Loading airing schedule…")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack {
                ErrorStateView(title: "Calendar Unavailable", message: message) {
                    Task { await viewModel.loadEvents() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            let sections = viewModel.groupedSections
            if sections.isEmpty {
                EmptyStateView(
                    title: viewModel.scope == .myList ? "No Upcoming Tracked Releases" : "No Upcoming Premieres",
                    message: viewModel.scope == .myList
                        ? "Tracked shows and anime airing in the selected timeframe will appear here."
                        : "Try clearing your date or category filter to view more releases.",
                    symbolName: "calendar.badge.clock"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections, id: \.day) { section in
                        Section(dayHeader(for: section.day)) {
                            ForEach(section.events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadEvents()
                }
            }
        }
    }

    private func eventRow(_ event: PremiereEvent) -> some View {
        HStack(spacing: CVSpacing.sm) {
            NavigationLink(value: Route.details(event.mediaReference)) {
                HStack(spacing: CVSpacing.sm) {
                    CachedAsyncImage(
                        url: event.posterURL,
                        targetSize: CGSize(width: 54, height: 81),
                        fallbackSymbol: event.kind.symbolName
                    )
                    .frame(width: 46, height: 69)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(CVFont.cardTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let episodeLabel = event.formattedEpisodeLabel {
                            Text(
                                event.episodeTitle.map { "\(episodeLabel) · \($0)" } ?? episodeLabel
                            )
                            .font(CVFont.caption.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                            .lineLimit(1)
                        } else if let subtitle = event.episodeTitle {
                            Text(subtitle)
                                .font(CVFont.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text(event.kind.displayName)
                            Text("•")
                            Text(event.date.formatted(date: .omitted, time: .shortened))
                        }
                        .font(CVFont.micro)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            if viewModel.isTracked(event.mediaReference.id) {
                let isEnabled = viewModel.alertsEnabled(for: event.mediaReference.id)
                Button {
                    Task {
                        await viewModel.toggleAlert(for: event)
                    }
                } label: {
                    Image(systemName: isEnabled ? "bell.fill" : "bell")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isEnabled ? CVColor.iris : Color.secondary)
                        .frame(width: 34, height: 34)
                        .background(
                            (isEnabled ? CVColor.iris.opacity(0.16) : Color(.tertiarySystemFill)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnabled ? "Disable Episode Alerts" : "Enable Episode Alerts")
            }
        }
        .padding(.vertical, 2)
    }

    private func dayHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today • \(CineVerseDateFormatters.dayAndMonthDisplay.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow • \(CineVerseDateFormatters.dayAndMonthDisplay.string(from: date))"
        }
        return CineVerseDateFormatters.dayAndMonthDisplay.string(from: date)
    }
}
