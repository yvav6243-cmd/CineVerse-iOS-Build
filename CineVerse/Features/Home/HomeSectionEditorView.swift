import SwiftUI

public struct HomeSectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sections: [HomeSectionConfiguration]

    private let settingsStore: SettingsStore
    private let onChanged: (() -> Void)?

    public init(settingsStore: SettingsStore, onChanged: (() -> Void)? = nil) {
        self.settingsStore = settingsStore
        self.onChanged = onChanged
        _sections = State(initialValue: Self.normalizedSections(from: settingsStore.homeSections))
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sections) { config in
                        HStack(spacing: CVSpacing.sm) {
                            Image(systemName: config.section.symbolName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(CVColor.iris)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(config.section.rawValue))
                                    .font(CVFont.cardTitle)
                                    .foregroundStyle(.primary)
                                Text(config.section.subtitle)
                                    .font(CVFont.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Toggle(
                                LocalizedStringKey(config.section.rawValue),
                                isOn: visibilityBinding(for: config.section)
                            )
                            .labelsHidden()
                            .tint(CVColor.iris)
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: moveSections)
                } header: {
                    Text("Order & Visibility")
                } footer: {
                    Text("Drag rows to reorder your Home feed, or toggle switches to hide sections you do not need.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset to Default") {
                        Haptics.impact(.light)
                        settingsStore.resetHomeSections()
                        sections = Self.normalizedSections(from: settingsStore.homeSections)
                        onChanged?()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func visibilityBinding(for section: HomeSectionType) -> Binding<Bool> {
        Binding(
            get: {
                sections.first(where: { $0.section == section })?.isVisible ?? true
            },
            set: { newValue in
                guard let index = sections.firstIndex(where: { $0.section == section }) else { return }
                Haptics.selection()
                sections[index].isVisible = newValue
                commitChanges()
            }
        )
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        Haptics.selection()
        sections.move(fromOffsets: source, toOffset: destination)
        commitChanges()
    }

    private func commitChanges() {
        for index in sections.indices {
            sections[index].sortOrder = index
        }
        settingsStore.homeSections = sections
        onChanged?()
    }

    private static func normalizedSections(from existing: [HomeSectionConfiguration]) -> [HomeSectionConfiguration] {
        var ordered = existing.sorted { $0.sortOrder < $1.sortOrder }
        let present = Set(ordered.map(\.section))
        for type in HomeSectionType.allCases where !present.contains(type) {
            ordered.append(HomeSectionConfiguration(section: type, isVisible: true, sortOrder: ordered.count))
        }
        for idx in ordered.indices {
            ordered[idx].sortOrder = idx
        }
        return ordered
    }
}
