import SwiftUI

public struct AddToListSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: MediaItem
    let entry: LibraryEntryRecord?
    let collections: [CustomCollectionRecord]
    let memberCollectionIDs: Set<UUID>

    let onToggleWatchlist: () -> Void
    let onToggleFavorite: () -> Void
    let onSelectStatus: (WatchTrackingStatus?) -> Void
    let onSetPersonalRating: (Double?) -> Void
    let onSetAlertsEnabled: (Bool) -> Void
    let onToggleCollection: (UUID) -> Void
    let onCreateCollection: (String, String) -> Void

    @State private var draftScore: Double = 0
    @State private var newCollectionName: String = ""
    @State private var newCollectionSymbol: String = "folder.fill"

    private let collectionSymbols: [String] = [
        "folder.fill",
        "star.fill",
        "heart.fill",
        "sparkles",
        "film.stack",
        "bookmark.fill",
        "flame.fill"
    ]

    public init(
        item: MediaItem,
        entry: LibraryEntryRecord?,
        collections: [CustomCollectionRecord],
        memberCollectionIDs: Set<UUID>,
        onToggleWatchlist: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onSelectStatus: @escaping (WatchTrackingStatus?) -> Void,
        onSetPersonalRating: @escaping (Double?) -> Void,
        onSetAlertsEnabled: @escaping (Bool) -> Void,
        onToggleCollection: @escaping (UUID) -> Void,
        onCreateCollection: @escaping (String, String) -> Void
    ) {
        self.item = item
        self.entry = entry
        self.collections = collections
        self.memberCollectionIDs = memberCollectionIDs
        self.onToggleWatchlist = onToggleWatchlist
        self.onToggleFavorite = onToggleFavorite
        self.onSelectStatus = onSelectStatus
        self.onSetPersonalRating = onSetPersonalRating
        self.onSetAlertsEnabled = onSetAlertsEnabled
        self.onToggleCollection = onToggleCollection
        self.onCreateCollection = onCreateCollection
        _draftScore = State(initialValue: entry?.personalRating ?? 0)
    }

    public var body: some View {
        NavigationStack {
            Form {
                quickFlagsSection
                trackingStatusSection
                personalScoreSection
                customCollectionsSection
            }
            .navigationTitle("Manage in Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var quickFlagsSection: some View {
        Section("Library Flags") {
            Toggle(
                isOn: Binding(
                    get: { entry?.inWatchlist ?? false },
                    set: { _ in
                        Haptics.selection()
                        onToggleWatchlist()
                    }
                )
            ) {
                Label("In Watchlist", systemImage: "bookmark.fill")
            }
            .tint(CVColor.iris)

            Toggle(
                isOn: Binding(
                    get: { entry?.isFavorite ?? false },
                    set: { _ in
                        Haptics.impact(.light)
                        onToggleFavorite()
                    }
                )
            ) {
                Label("Favorite", systemImage: "heart.fill")
            }
            .tint(.pink)

            if item.projectType.isEpisodic {
                Toggle(
                    isOn: Binding(
                        get: { entry?.alertsEnabled ?? false },
                        set: { enabled in
                            Haptics.selection()
                            onSetAlertsEnabled(enabled)
                        }
                    )
                ) {
                    Label("Episode Release Alerts", systemImage: "bell.badge.fill")
                }
                .tint(CVColor.iris)
            }
        }
    }

    private var trackingStatusSection: some View {
        Section("Tracking Status") {
            ForEach(WatchTrackingStatus.allCases) { status in
                let isSelected = entry?.status == status
                Button {
                    Haptics.selection()
                    onSelectStatus(isSelected ? nil : status)
                } label: {
                    HStack(spacing: CVSpacing.sm) {
                        Image(systemName: status.symbolName)
                            .foregroundStyle(Color(hex: status.accentHex))
                            .frame(width: 22)

                        Text(LocalizedStringKey(status.rawValue))
                            .foregroundStyle(.primary)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(CVColor.iris)
                        }
                    }
                }
            }
        }
    }

    private var personalScoreSection: some View {
        Section("Personal Score") {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                HStack {
                    Text("Score")
                        .font(CVFont.callout)
                    Spacer()
                    Text(draftScore > 0 ? String(format: "%.1f / 10", draftScore) : "Unrated")
                        .font(CVFont.callout.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(draftScore > 0 ? CVColor.iris : .secondary)
                }

                Slider(value: $draftScore, in: 0...10, step: 0.5)
                    .tint(CVColor.iris)
                    .onChange(of: draftScore) { _, newValue in
                        onSetPersonalRating(newValue > 0 ? newValue : nil)
                    }

                if draftScore > 0 {
                    Button("Clear Score", role: .destructive) {
                        Haptics.selection()
                        draftScore = 0
                        onSetPersonalRating(nil)
                    }
                    .font(CVFont.caption.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var customCollectionsSection: some View {
        Section("Custom Collections") {
            if collections.isEmpty {
                Text("No collections yet. Create one below.")
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collections) { collection in
                    let isMember = memberCollectionIDs.contains(collection.id)
                    Button {
                        Haptics.selection()
                        onToggleCollection(collection.id)
                    } label: {
                        HStack(spacing: CVSpacing.sm) {
                            Image(systemName: collection.symbolName)
                                .foregroundStyle(CVColor.iris)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.name)
                                    .foregroundStyle(.primary)
                                Text("\(collection.items.count) items")
                                    .font(CVFont.micro)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: isMember ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isMember ? CVColor.iris : Color.secondary)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: CVSpacing.xs) {
                Text("Create Collection")
                    .font(CVFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: CVSpacing.xs) {
                    TextField("Collection name", text: $newCollectionName)
                        .textFieldStyle(.roundedBorder)

                    Button("Create") {
                        let trimmed = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Haptics.notify(.success)
                        onCreateCollection(trimmed, newCollectionSymbol)
                        newCollectionName = ""
                    }
                    .buttonStyle(CVPrimaryButtonStyle(compact: true))
                    .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CVSpacing.xs) {
                        ForEach(collectionSymbols, id: \.self) { symbol in
                            Button {
                                Haptics.selection()
                                newCollectionSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.subheadline)
                                    .foregroundStyle(newCollectionSymbol == symbol ? Color.white : Color.primary)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        newCollectionSymbol == symbol
                                            ? CVColor.iris
                                            : Color(.tertiarySystemFill),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
        }
    }
}
