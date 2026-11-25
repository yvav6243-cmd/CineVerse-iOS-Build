import SwiftUI

public enum CVSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
}

public enum CVRadius {
    public static let chip: CGFloat = 10
    public static let poster: CGFloat = 12
    public static let card: CGFloat = 14
    public static let panel: CGFloat = 20
}

public enum CVFont {
    public static let heroTitle: Font = .system(.title2, design: .rounded, weight: .bold)
    public static let pageTitle: Font = .system(.title3, design: .rounded, weight: .bold)
    public static let sectionTitle: Font = .system(.headline, design: .rounded, weight: .bold)
    public static let cardTitle: Font = .system(.footnote, design: .default, weight: .semibold)
    public static let body: Font = .system(.subheadline, design: .default, weight: .regular)
    public static let callout: Font = .system(.footnote, design: .default, weight: .medium)
    public static let caption: Font = .system(.caption, design: .default, weight: .medium)
    public static let micro: Font = .system(.caption2, design: .default, weight: .semibold)
}

public enum CVColor {
    public static let accent = Color("AccentColor")
    public static let iris = Color(hex: "#6E5BFF")
    public static let secondarySurface = Color(.secondarySystemBackground)
    public static let tertiarySurface = Color(.tertiarySystemBackground)
    public static let background = Color(.systemBackground)
    public static let canvas = Color(.systemBackground)
    public static let groupedBackground = Color(.systemGroupedBackground)
    public static let primaryLabel = Color(.label)
    public static let secondaryLabel = Color(.secondaryLabel)
    public static let tertiaryLabel = Color(.tertiaryLabel)
    public static let separator = Color(.separator)
    public static let ratingGold = Color(hex: "#FFD60A")
    public static let success = Color(hex: "#30D158")
    public static let warning = Color(hex: "#FF9F0A")
    public static let amber = Color(hex: "#FF9F0A")
    public static let danger = Color(hex: "#FF453A")

    public static var irisGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#7D6BFF"), Color(hex: "#5B46E8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var brandGradient: LinearGradient {
        irisGradient
    }
}

public enum CVGridLayoutMetrics {
    public static func columnCount(
        for containerWidth: CGFloat,
        horizontalPadding: CGFloat = CVSpacing.md * 2,
        spacing: CGFloat = CVSpacing.sm,
        minCardWidth: CGFloat = 104
    ) -> Int {
        guard containerWidth.isFinite, containerWidth > 0 else { return 2 }
        let usable = max(containerWidth - horizontalPadding, minCardWidth * 2 + spacing)
        let computed = Int(floor((usable + spacing) / (minCardWidth + spacing)))
        return min(max(computed, 2), 6)
    }

    public static func cardWidth(
        for containerWidth: CGFloat,
        horizontalPadding: CGFloat = CVSpacing.md * 2,
        spacing: CGFloat = CVSpacing.sm
    ) -> CGFloat {
        guard containerWidth.isFinite, containerWidth > 0 else { return 114 }
        let cols = columnCount(for: containerWidth, horizontalPadding: horizontalPadding, spacing: spacing)
        let usable = max(containerWidth - horizontalPadding, 220)
        let raw = floor((usable - spacing * CGFloat(cols - 1)) / CGFloat(cols))
        return min(max(raw, 96), 160)
    }

    public static func columns(
        for containerWidth: CGFloat,
        spacing: CGFloat = CVSpacing.sm
    ) -> [GridItem] {
        let count = columnCount(for: containerWidth, spacing: spacing)
        return Array(
            repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
            count: count
        )
    }
}

public enum CVMotion {
    public static let spring: Animation = .spring(response: 0.42, dampingFraction: 0.86)
    public static let snappy: Animation = .snappy(duration: 0.28, extraBounce: 0.04)
    public static let gentle: Animation = .easeInOut(duration: 0.25)
}
