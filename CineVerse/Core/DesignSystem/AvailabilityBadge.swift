import SwiftUI

public struct AvailabilityBadge: View {
    let status: ContentAvailabilityStatus
    var compact: Bool = true
    var detailText: String? = nil

    public init(
        status: ContentAvailabilityStatus,
        compact: Bool = true,
        detailText: String? = nil
    ) {
        self.status = status
        self.compact = compact
        self.detailText = detailText
    }

    public var body: some View {
        let accent = Color(hex: status.accentHex)
        let title = compact ? status.shortBadge : status.rawValue
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.system(size: compact ? 9 : 11, weight: .bold))
            Text(title)
                .font(compact ? CVFont.micro : CVFont.caption.weight(.bold))
                .lineLimit(1)
            if let detailText, !detailText.isEmpty {
                Text("· \(detailText)")
                    .font(compact ? CVFont.micro : CVFont.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(accent)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(accent.opacity(0.16), in: Capsule(style: .continuous))
    }
}
