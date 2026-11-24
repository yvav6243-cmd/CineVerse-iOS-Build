import SwiftUI

public struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var symbolName: String? = nil
    var actionTitle: String? = "See All"
    var action: (() -> Void)? = nil

    public init(
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        actionTitle: String? = "See All",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: CVSpacing.xs) {
                    if let symbolName {
                        Image(systemName: symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                    }
                    Text(LocalizedStringKey(title))
                        .font(CVFont.sectionTitle)
                        .foregroundStyle(.primary)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let action, let actionTitle {
                Button {
                    Haptics.selection()
                    action()
                } label: {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey(actionTitle))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(CVFont.callout)
                    .foregroundStyle(CVColor.iris)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CVSpacing.md)
    }
}
