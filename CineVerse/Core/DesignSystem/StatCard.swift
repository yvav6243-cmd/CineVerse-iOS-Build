import SwiftUI

public struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let symbolName: String
    var accent: Color = CVColor.iris

    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        symbolName: String,
        accent: Color = CVColor.iris
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.accent = accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(CVFont.micro)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(CVSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }
}
