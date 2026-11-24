import SwiftUI

public struct CVProgressBar: View {
    let fraction: Double
    var height: CGFloat = 4
    var tint: Color = CVColor.iris
    var trackColor: Color = Color.white.opacity(0.24)

    public init(
        fraction: Double,
        height: CGFloat = 4,
        tint: Color = CVColor.iris,
        trackColor: Color = Color.white.opacity(0.24)
    ) {
        self.fraction = min(max(fraction, 0), 1)
        self.height = height
        self.tint = tint
        self.trackColor = trackColor
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: max(proxy.size.width * fraction, fraction > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}
