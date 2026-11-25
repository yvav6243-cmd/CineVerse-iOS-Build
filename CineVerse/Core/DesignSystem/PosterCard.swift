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
                .clipped()

                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.42), location: 0.0),
                        .init(color: Color.clear, location: 0.28),
                        .init(color: Color.clear, location: 0.78),
                        .init(color: Color.black.opacity((progressFraction ?? 0) > 0.01 ? 0.62 : 0.16), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: CVSpacing.xs) {
                    HStack(spacing: 4) {
                        TypeBadge(projectType: item.projectType)
                        Spacer(minLength: 2)
                        RatingBadge(score: item.displayRating)
                            .layoutPriority(1)
                    }
                    .environment(\.colorScheme, .dark)
                    .padding(.horizontal, 7)
                    .padding(.top, 7)

                    Spacer()

                    if let progressFraction, progressFraction > 0.01 {
                        CVProgressBar(fraction: progressFraction, height: 4)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: width, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6)
            )
            .cvMatchedSource(id: transitionID ?? item.id, in: transitionNamespace)
            .shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 6)

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
