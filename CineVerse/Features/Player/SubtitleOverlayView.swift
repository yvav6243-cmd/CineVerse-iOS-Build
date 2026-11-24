import SwiftUI

public struct SubtitleOverlayView: View {
    let text: String?
    let style: SubtitleAppearanceStyle
    let controlsVisible: Bool

    public init(text: String?, style: SubtitleAppearanceStyle, controlsVisible: Bool) {
        self.text = text
        self.style = style
        self.controlsVisible = controlsVisible
    }

    public var body: some View {
        VStack {
            Spacer()
            if let text, !text.isEmpty {
                Text(text)
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
                    .padding(.horizontal, 28)
                    .padding(.bottom, controlsVisible ? 116 : 32)
                    .animation(CVMotion.snappy, value: controlsVisible)
            }
        }
        .allowsHitTesting(false)
    }
}
