import SwiftUI

public struct SubtitleStyleSettingsView: View {
    let settingsStore: SettingsStore

    private let textColorPresets: [(name: String, hex: String)] = [
        ("White", "#FFFFFF"),
        ("Gold", "#FFD60A"),
        ("Sky", "#64D2FF"),
        ("Mint", "#30D158"),
        ("Coral", "#FF6482")
    ]

    private let backgroundColorPresets: [(name: String, hex: String)] = [
        ("Black", "#000000"),
        ("Charcoal", "#1C1C1E"),
        ("Midnight", "#0D1B2A"),
        ("Iris", "#2A2356")
    ]

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        @Bindable var store = settingsStore

        Form {
            Section("Preview") {
                previewBox(style: store.subtitleStyle)
                    .listRowInsets(EdgeInsets())
            }

            Section("Text") {
                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(store.subtitleStyle.fontSize.rounded())) pt")
                            .font(CVFont.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $store.subtitleStyle.fontSize,
                        in: 12...32,
                        step: 1
                    )
                    .tint(CVColor.iris)
                }

                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    Text("Text Color")
                        .font(CVFont.callout)
                    HStack(spacing: CVSpacing.sm) {
                        ForEach(textColorPresets, id: \.hex) { preset in
                            colorSwatch(
                                hex: preset.hex,
                                label: preset.name,
                                isSelected: store.subtitleStyle.textColorHex.uppercased() == preset.hex
                            ) {
                                store.subtitleStyle.textColorHex = preset.hex
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Backdrop Box") {
                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    Text("Background Color")
                        .font(CVFont.callout)
                    HStack(spacing: CVSpacing.sm) {
                        ForEach(backgroundColorPresets, id: \.hex) { preset in
                            colorSwatch(
                                hex: preset.hex,
                                label: preset.name,
                                isSelected: store.subtitleStyle.backgroundColorHex.uppercased() == preset.hex
                            ) {
                                store.subtitleStyle.backgroundColorHex = preset.hex
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: CVSpacing.xs) {
                    HStack {
                        Text("Background Opacity")
                        Spacer()
                        Text("\(Int((store.subtitleStyle.backgroundOpacity * 100).rounded()))%")
                            .font(CVFont.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $store.subtitleStyle.backgroundOpacity,
                        in: 0...1,
                        step: 0.05
                    )
                    .tint(CVColor.iris)
                }
            }

            Section {
                Button("Reset to Default Style") {
                    Haptics.selection()
                    store.subtitleStyle = SubtitleAppearanceStyle()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Subtitle Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewBox(style: SubtitleAppearanceStyle) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(hex: "#1A1830"),
                    Color(hex: "#312B59"),
                    Color(hex: "#0D0E14")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.white.opacity(0.08))
            }

            Text("The truth was never hidden in the stars.")
                .font(.system(size: style.fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: style.textColorHex))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Color(hex: style.backgroundColorHex).opacity(style.backgroundOpacity),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
        }
        .frame(height: 190)
        .clipped()
    }

    private func colorSwatch(
        hex: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                )
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(CVColor.iris, lineWidth: 3)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
