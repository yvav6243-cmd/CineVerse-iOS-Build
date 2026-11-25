import SwiftUI

public struct DetailsHeaderView: View {
    let item: MediaItem
    let transitionID: String
    let transitionNamespace: Namespace.ID?

    private let backdropHeight: CGFloat = 176

    public init(
        item: MediaItem,
        transitionID: String,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.item = item
        self.transitionID = transitionID
        self.transitionNamespace = transitionNamespace
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.md) {
            stretchyBackdrop

            HStack(alignment: .bottom, spacing: CVSpacing.md) {
                posterCard
                titleAndMetadataColumn
            }
            .padding(.horizontal, CVSpacing.md)
            .padding(.top, -54)

            if !item.genres.isEmpty {
                GenreWrapLayout(spacing: CVSpacing.xs, rowSpacing: CVSpacing.xs) {
                    ForEach(item.genres, id: \.self) { genre in
                        GenreChip(title: genre)
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }

    private var stretchyBackdrop: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("detailsScroll")).minY
            let extraHeight = max(0, minY)
            let parallaxOffset = minY < 0 ? -minY * 0.35 : -minY

            ZStack(alignment: .bottom) {
                CachedAsyncImage(
                    url: item.backdropURL ?? item.posterURL,
                    targetSize: CGSize(width: 900, height: 520),
                    fallbackSymbol: item.projectType.symbolName
                )
                .frame(width: proxy.size.width, height: backdropHeight + extraHeight)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.16), location: 0.0),
                            .init(color: Color(.systemBackground).opacity(0.55), location: 0.56),
                            .init(color: Color(.systemBackground).opacity(0.95), location: 0.84),
                            .init(color: Color(.systemBackground), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: proxy.size.width, height: backdropHeight + extraHeight)
            .offset(y: parallaxOffset)
        }
        .frame(height: backdropHeight)
    }

    private var posterCard: some View {
        CachedAsyncImage(
            url: item.posterURL,
            targetSize: CGSize(width: 200, height: 300),
            fallbackSymbol: item.projectType.symbolName
        )
        .frame(width: 92, height: 138)
        .clipShape(RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 5)
        .cvMatchedSource(id: transitionID, in: transitionNamespace)
    }

    private var titleAndMetadataColumn: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack(spacing: CVSpacing.xs) {
                TypeBadge(projectType: item.projectType)
                StatusBadge(releaseStatus: item.releaseStatus)
            }

            Text(item.localizedTitle)
                .font(CVFont.pageTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowOriginalTitle {
                Text(item.originalTitle)
                    .font(CVFont.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            metadataLine

            if !item.director.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "person.text.rectangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CVColor.iris)
                    Text(item.director)
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataLine: some View {
        let segments = metadataSegments
        return HStack(spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text("•")
                        .foregroundStyle(.tertiary)
                }
                Text(segment)
            }
        }
        .font(CVFont.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var metadataSegments: [String] {
        var parts: [String] = []
        if item.releaseYear > 0 {
            parts.append(String(item.releaseYear))
        }
        if !item.countryOfOrigin.isEmpty {
            let country = Locale.current.localizedString(forRegionCode: item.countryOfOrigin)
                ?? item.countryOfOrigin
            parts.append(country)
        }
        if !item.ageRating.isEmpty {
            parts.append(item.ageRating)
        }
        let duration = item.formattedDuration
        if !duration.isEmpty {
            parts.append(duration)
        }
        return parts
    }

    private var shouldShowOriginalTitle: Bool {
        guard !item.originalTitle.isEmpty else { return false }
        return item.originalTitle.normalizedForComparison != item.localizedTitle.normalizedForComparison
    }
}

private struct GenreWrapLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                maxRowWidth = max(maxRowWidth, currentX - spacing)
                currentX = 0
                currentY += rowHeight + rowSpacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        maxRowWidth = max(maxRowWidth, max(0, currentX - spacing))
        return CGSize(width: maxRowWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + rowSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
