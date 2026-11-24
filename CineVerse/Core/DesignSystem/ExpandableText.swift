import SwiftUI

public struct ExpandableText: View {
    let text: String
    var lineLimit: Int = 4

    @State private var isExpanded: Bool = false

    public init(text: String, lineLimit: Int = 4) {
        self.text = text
        self.lineLimit = lineLimit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(CVFont.body)
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(isExpanded ? nil : lineLimit)
                .animation(CVMotion.gentle, value: isExpanded)

            if text.count > 160 {
                Button(isExpanded ? "Show Less" : "Read More") {
                    withAnimation(CVMotion.snappy) {
                        isExpanded.toggle()
                    }
                }
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .buttonStyle(.plain)
            }
        }
    }
}
