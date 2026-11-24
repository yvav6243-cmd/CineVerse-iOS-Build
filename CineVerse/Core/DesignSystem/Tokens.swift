import SwiftUI

public enum CVSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum CVRadius {
    public static let chip: CGFloat = 12
    public static let poster: CGFloat = 14
    public static let card: CGFloat = 18
    public static let panel: CGFloat = 28
}

public enum CVFont {
    public static let heroTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    public static let pageTitle: Font = .system(.title2, design: .rounded, weight: .bold)
    public static let sectionTitle: Font = .system(.title3, design: .rounded, weight: .bold)
    public static let cardTitle: Font = .system(.subheadline, design: .default, weight: .semibold)
    public static let body: Font = .system(.body, design: .default, weight: .regular)
    public static let callout: Font = .system(.callout, design: .default, weight: .medium)
    public static let caption: Font = .system(.caption, design: .default, weight: .medium)
    public static let micro: Font = .system(.caption2, design: .default, weight: .semibold)
}

public enum CVColor {
    public static let accent = Color("AccentColor")
    public static let iris = Color(hex: "#6E5BFF")
    public static let secondarySurface = Color(.secondarySystemBackground)
    public static let tertiarySurface = Color(.tertiarySystemBackground)
    public static let background = Color(.systemBackground)
    public static let groupedBackground = Color(.systemGroupedBackground)
    public static let primaryLabel = Color(.label)
    public static let secondaryLabel = Color(.secondaryLabel)
    public static let tertiaryLabel = Color(.tertiaryLabel)
    public static let separator = Color(.separator)
    public static let ratingGold = Color(hex: "#FFD60A")
    public static let success = Color(hex: "#30D158")
    public static let warning = Color(hex: "#FF9F0A")
    public static let danger = Color(hex: "#FF453A")
}

public enum CVMotion {
    public static let spring: Animation = .spring(response: 0.42, dampingFraction: 0.86)
    public static let snappy: Animation = .snappy(duration: 0.28, extraBounce: 0.04)
    public static let gentle: Animation = .easeInOut(duration: 0.25)
}
