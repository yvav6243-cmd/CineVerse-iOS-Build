import SwiftUI

public struct MediaRail<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    public init(
        items: [Item],
        spacing: CGFloat = CVSpacing.sm,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, CVSpacing.md, for: .scrollContent)
    }
}
