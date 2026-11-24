import SwiftUI

public struct FilterChip: View {
    let title: String
    var symbolName: String? = nil
    let isSelected: Bool
    let action: () -> Void

    public init(
        title: String,
        symbolName: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbolName = symbolName
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 5) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(CVFont.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, CVSpacing.sm)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(CVColor.iris)
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.clear)
                        .cvGlass(Capsule(style: .continuous), interactive: true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

public struct GenreChip: View {
    let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(CVFont.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: Capsule(style: .continuous))
    }
}
