import SwiftUI

public struct PosterCard: View {
    let item: MediaItem
    var width: CGFloat = 148
    var progressFraction: Double? = nil
    var transitionNamespace: Namespace.ID? = nil
    var transitionID: String? = nil

    private var posterHeight: CGFloat { width * 1.5 }

    public init(
        item: MediaItem,
        width: CGFloat = 148,
        progressFraction: Double? = nil,
        transitionNamespace: Namespace.ID? = nil,
        transitionID: String? = nil
    ) {
        self.item = item
        self.width = width
        self.progressFraction = progressFraction
        self.transitionNamespace = transitionNamespace
        self.transitionID = transitionID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            ZStack(alignment: .bottom) {
                CachedAsyncImage(
                    url: item.posterURL,
                    targetSize: CGSize(width: width, height: posterHeight),
                    fallbackSymbol: item.projectType.symbolName
                )
                .frame(width: width, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .cvMatchedSource(id: transitionID ?? item.id, in: transitionNamespace)

                VStack(spacing: CVSpacing.xs) {
                    HStack {
                        TypeBadge(projectType: item.projectType)
                        Spacer(minLength: 4)
                        RatingBadge(score: item.displayRating)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    Spacer()

                    if let progressFraction, progressFraction > 0.01 {
                        CVProgressBar(fraction: progressFraction, height: 4)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: width, height: posterHeight)
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedTitle)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if item.releaseYear > 0 {
                        Text(String(item.releaseYear))
                    }
                    if !item.genres.isEmpty {
                        Text("•")
                        Text(item.genres[0])
                    }
                }
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}
