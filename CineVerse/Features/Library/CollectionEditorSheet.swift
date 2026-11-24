import SwiftUI

public struct CollectionEditorSheet: View {
    private let existingCollection: CustomCollectionRecord?
    private let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedSymbol: String

    private let presetSuggestions: [(title: String, symbol: String)] = [
        ("Must Watch", "star.fill"),
        ("Best Anime", "sparkles.tv"),
        ("Favorite Movies", "film.fill"),
        ("To Watch Later", "bookmark.fill")
    ]

    private let curatedSymbols: [String] = [
        "folder.fill", "star.fill", "heart.fill", "film.fill",
        "film.stack", "tv.fill", "sparkles.tv", "popcorn.fill",
        "theatermasks.fill", "ticket.fill", "bookmark.fill", "flame.fill",
        "bolt.fill", "crown.fill", "trophy.fill", "sparkles",
        "moon.stars.fill", "clock.fill", "eye.fill", "play.rectangle.fill",
        "music.note.tv.fill", "globe.desk.fill", "books.vertical.fill", "rectangle.stack.fill"
    ]

    public init(
        existingCollection: CustomCollectionRecord? = nil,
        onSave: @escaping (String, String) -> Void
    ) {
        self.existingCollection = existingCollection
        self.onSave = onSave
        _name = State(initialValue: existingCollection?.name ?? "")
        _selectedSymbol = State(initialValue: existingCollection?.symbolName ?? "folder.fill")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    HStack(spacing: CVSpacing.sm) {
                        Image(systemName: selectedSymbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                            .frame(width: 38, height: 38)
                            .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        TextField("e.g. Weekend Sci-Fi", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                }

                if existingCollection == nil {
                    Section("Quick Presets") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: CVSpacing.xs) {
                                ForEach(presetSuggestions, id: \.title) { preset in
                                    FilterChip(
                                        title: preset.title,
                                        symbolName: preset.symbol,
                                        isSelected: trimmedName == preset.title
                                    ) {
                                        name = preset.title
                                        selectedSymbol = preset.symbol
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Choose Icon") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 44), spacing: CVSpacing.xs)],
                        spacing: CVSpacing.xs
                    ) {
                        ForEach(curatedSymbols, id: \.self) { symbol in
                            let isSelected = selectedSymbol == symbol
                            Button {
                                Haptics.selection()
                                selectedSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        isSelected ? CVColor.iris : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingCollection == nil ? "New Collection" : "Rename Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingCollection == nil ? "Create" : "Save") {
                        guard !trimmedName.isEmpty else { return }
                        Haptics.notify(.success)
                        onSave(trimmedName, selectedSymbol)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
