import SwiftUI

public struct ShimmerRail: View {
    var cardWidth: CGFloat = 148
    var count: Int = 4

    public init(cardWidth: CGFloat = 148, count: Int = 4) {
        self.cardWidth = cardWidth
        self.count = count
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CVSpacing.sm) {
                ForEach(0..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: CVSpacing.xs) {
                        RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: cardWidth, height: cardWidth * 1.5)
                            .cvShimmer(true)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: cardWidth * 0.78, height: 12)
                            .cvShimmer(true)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: cardWidth * 0.45, height: 10)
                            .cvShimmer(true)
                    }
                }
            }
            .padding(.horizontal, CVSpacing.md)
        }
        .allowsHitTesting(false)
    }
}

public struct ShimmerHeroCard: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 380)
            .overlay(
                RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, CVSpacing.md)
            .cvShimmer(true)
    }
}

public struct ErrorStateView: View {
    let title: String
    let message: String
    var symbolName: String = "exclamationmark.triangle"
    var actionTitle: String = "Try Again"
    let retryAction: () -> Void

    public init(
        title: String = "Could Not Load Content",
        message: String,
        symbolName: String = "exclamationmark.triangle",
        actionTitle: String = "Try Again",
        retryAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.actionTitle = actionTitle
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: CVSpacing.sm) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(CVColor.warning)

            Text(title)
                .font(CVFont.cardTitle)
                .foregroundStyle(.primary)

            Text(message)
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button(actionTitle) {
                Haptics.impact(.light)
                retryAction()
            }
            .buttonStyle(CVGlassButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity)
        .padding(CVSpacing.lg)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
    }
}

public struct EmptyStateView: View {
    let title: String
    let message: String
    let symbolName: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    public init(
        title: String,
        message: String,
        symbolName: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CVPrimaryButtonStyle(compact: true))
            }
        }
    }
}

public struct CompactHintCard: View {
    let symbolName: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    public init(
        symbolName: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: CVSpacing.sm) {
            Image(systemName: symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .frame(width: 40, height: 40)
                .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(CVFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(CVGlassButtonStyle(compact: true))
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
    }
}
