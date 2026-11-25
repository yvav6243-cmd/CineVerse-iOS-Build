import SwiftUI

public struct RatingBadge: View {
    let score: Double
    var compact: Bool = true

    public init(score: Double, compact: Bool = true) {
        self.score = score
        self.compact = compact
    }

    public var body: some View {
        if score.isFinite && score > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: compact ? 9 : 11, weight: .bold))
                    .foregroundStyle(CVColor.ratingGold)
                Text(String(format: "%.1f", min(score, 10.0)))
                    .font(compact ? CVFont.micro : CVFont.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
    }
}

public struct TypeBadge: View {
    let projectType: MediaProjectType
    var iconOnly: Bool = false

    public init(projectType: MediaProjectType, iconOnly: Bool = false) {
        self.projectType = projectType
        self.iconOnly = iconOnly
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: projectType.symbolName)
                .font(.system(size: 9, weight: .semibold))
            if !iconOnly {
                Text(projectType.displayName)
                    .font(CVFont.micro)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, iconOnly ? 5 : 7)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

public struct StatusBadge: View {
    let text: String
    let accentHex: String
    var symbolName: String? = nil

    public init(text: String, accentHex: String, symbolName: String? = nil) {
        self.text = text
        self.accentHex = accentHex
        self.symbolName = symbolName
    }

    public init(trackingStatus: WatchTrackingStatus) {
        self.text = trackingStatus.rawValue
        self.accentHex = trackingStatus.accentHex
        self.symbolName = trackingStatus.symbolName
    }

    public init(releaseStatus: MediaReleaseStatus) {
        self.text = releaseStatus.rawValue
        self.accentHex = releaseStatus.badgeColorHex
        self.symbolName = nil
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 10, weight: .semibold))
            } else {
                Circle()
                    .fill(Color(hex: accentHex))
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(CVFont.micro)
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: accentHex))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: accentHex).opacity(0.16), in: Capsule(style: .continuous))
    }
}
