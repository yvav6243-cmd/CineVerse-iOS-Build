import SwiftUI

public struct CVPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? CVFont.caption.weight(.semibold) : CVFont.callout.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, compact ? CVSpacing.md : CVSpacing.lg)
            .padding(.vertical, compact ? CVSpacing.xs + 2 : CVSpacing.sm + 2)
            .background(
                CVColor.iris,
                in: Capsule(style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(CVMotion.snappy, value: configuration.isPressed)
    }
}

public struct CVGlassButtonStyle: ButtonStyle {
    var compact: Bool = false
    var tint: Color? = nil

    public init(compact: Bool = false, tint: Color? = nil) {
        self.compact = compact
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? CVFont.caption.weight(.semibold) : CVFont.callout.weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, compact ? CVSpacing.sm : CVSpacing.md)
            .padding(.vertical, compact ? CVSpacing.xs + 1 : CVSpacing.sm)
            .cvGlass(Capsule(style: .continuous), interactive: true, tint: tint)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(CVMotion.snappy, value: configuration.isPressed)
    }
}

public struct CVIconButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var size: CGFloat = 38
    var tint: Color? = nil
    let action: () -> Void

    public init(
        symbolName: String,
        accessibilityLabel: String,
        size: CGFloat = 38,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.accessibilityLabel = accessibilityLabel
        self.size = size
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: size, height: size)
                .cvGlass(Circle(), interactive: true, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
