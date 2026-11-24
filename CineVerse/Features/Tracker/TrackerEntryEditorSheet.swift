import SwiftUI

public struct TrackerEntryEditorSheet: View {
    let entry: LibraryEntryRecord
    let viewModel: TrackerViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedStatus: WatchTrackingStatus?
    @State private var ratingValue: Double
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasFinishDate: Bool
    @State private var finishDate: Date
    @State private var rewatchCount: Int
    @State private var notes: String
    @State private var showDeleteConfirmation: Bool = false

    public init(entry: LibraryEntryRecord, viewModel: TrackerViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        _selectedStatus = State(initialValue: entry.status)
        _ratingValue = State(initialValue: entry.personalRating ?? 0)
        _hasStartDate = State(initialValue: entry.startDate != nil)
        _startDate = State(initialValue: entry.startDate ?? Date())
        _hasFinishDate = State(initialValue: entry.finishDate != nil)
        _finishDate = State(initialValue: entry.finishDate ?? Date())
        _rewatchCount = State(initialValue: entry.rewatchCount)
        _notes = State(initialValue: entry.notes)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    HStack(spacing: CVSpacing.sm) {
                        CachedAsyncImage(
                            url: entry.posterURL,
                            targetSize: CGSize(width: 56, height: 84),
                            fallbackSymbol: entry.projectType.symbolName
                        )
                        .frame(width: 48, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(CVFont.cardTitle)
                                .lineLimit(2)
                            TypeBadge(projectType: entry.projectType)
                        }
                    }
                }

                Section("Tracking Status") {
                    Picker("Status", selection: $selectedStatus) {
                        Text("None").tag(WatchTrackingStatus?.none)
                        ForEach(WatchTrackingStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.symbolName)
                                .tag(WatchTrackingStatus?.some(status))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    VStack(alignment: .leading, spacing: CVSpacing.xs) {
                        HStack {
                            Text("Personal Rating")
                            Spacer()
                            if ratingValue > 0 {
                                Text(String(format: "%.1f / 10", ratingValue))
                                    .font(CVFont.callout.weight(.semibold))
                                    .foregroundStyle(CVColor.ratingGold)
                                    .monospacedDigit()
                            } else {
                                Text("Unrated")
                                    .font(CVFont.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Slider(value: $ratingValue, in: 0...10, step: 0.5)
                            .tint(CVColor.iris)

                        if ratingValue > 0 {
                            Button("Clear Rating") {
                                ratingValue = 0
                            }
                            .font(CVFont.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Rating")
                }

                if entry.projectType.isEpisodic {
                    Section("Episodes Watched") {
                        let seasons = viewModel.seasonProgress(for: entry)
                        ForEach(seasons, id: \.seasonNumber) { season in
                            Stepper(
                                value: Binding(
                                    get: { season.watched },
                                    set: { newValue in
                                        viewModel.setSeasonWatchedCount(
                                            newValue,
                                            forSeason: season.seasonNumber,
                                            total: season.total,
                                            in: entry
                                        )
                                    }
                                ),
                                in: 0...max(season.total, 1)
                            ) {
                                HStack {
                                    Text("Season \(season.seasonNumber)")
                                    Spacer()
                                    Text("\(season.watched) / \(season.total)")
                                        .font(CVFont.callout)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                Section("Dates & Rewatches") {
                    Toggle("Start Date", isOn: $hasStartDate.animation())
                    if hasStartDate {
                        DatePicker("Started", selection: $startDate, displayedComponents: .date)
                    }

                    Toggle("Finish Date", isOn: $hasFinishDate.animation())
                    if hasFinishDate {
                        DatePicker("Finished", selection: $finishDate, displayedComponents: .date)
                    }

                    Stepper("Rewatches: \(rewatchCount)", value: $rewatchCount, in: 0...99)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 88)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete from Tracker", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Edit Tracker Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Remove \"\(entry.title)\" from Tracker?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete from Tracker", role: .destructive) {
                    viewModel.deleteEntry(entry)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes this project from your library and tracker.")
            }
        }
    }

    private func saveAndDismiss() {
        viewModel.updateEntry(
            entry,
            status: selectedStatus,
            personalRating: ratingValue > 0 ? ratingValue : nil,
            startDate: hasStartDate ? startDate : nil,
            finishDate: hasFinishDate ? finishDate : nil,
            rewatchCount: rewatchCount,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Haptics.notify(.success)
        dismiss()
    }
}
