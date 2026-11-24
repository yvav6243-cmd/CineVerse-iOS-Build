import SwiftUI

public struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mediaTitle: String
    let onSave: (String) -> Void

    @State private var draftNotes: String
    @FocusState private var isFocused: Bool

    public init(
        mediaTitle: String,
        initialNotes: String,
        onSave: @escaping (String) -> Void
    ) {
        self.mediaTitle = mediaTitle
        self.onSave = onSave
        _draftNotes = State(initialValue: initialNotes)
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                HStack {
                    Text(mediaTitle)
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(draftNotes.count) chars")
                        .font(CVFont.micro)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draftNotes)
                        .focused($isFocused)
                        .font(CVFont.body)
                        .scrollContentBackground(.hidden)
                        .padding(CVSpacing.sm)

                    if draftNotes.isEmpty {
                        Text("Write personal notes, episode thoughts, rewatch reminders, or favorite quotes...")
                            .font(CVFont.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, CVSpacing.sm + 5)
                            .padding(.vertical, CVSpacing.sm + 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cvCardBackground(cornerRadius: CVRadius.card)

                if !draftNotes.isEmpty {
                    Button("Clear Notes", role: .destructive) {
                        Haptics.selection()
                        draftNotes = ""
                    }
                    .font(CVFont.caption.weight(.semibold))
                }
            }
            .padding(CVSpacing.md)
            .navigationTitle("Personal Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Haptics.notify(.success)
                        onSave(draftNotes.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
