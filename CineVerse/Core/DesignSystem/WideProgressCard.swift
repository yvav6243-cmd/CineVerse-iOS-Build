import SwiftUI

public struct WideProgressCard: View {
    let title: String
    let subtitle: String
    let imageURL: URL?
    let projectType: MediaProjectType
    let progressFraction: Double
    var width: CGFloat = 276

    private var cardHeight: CGFloat { width * 9.0 / 16.0 }

    public init(
        title: String,
        subtitle: String,
        imageURL: URL?,
        projectType: MediaProjectType,
        progressFraction: Double,
        width: CGFloat = 276
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.projectType = projectType
        self.progressFraction = progressFraction
        self.width = width
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(
                    url: imageURL,
                    targetSize: CGSize(width: width, height: cardHeight),
                    fallbackSymbol: projectType.symbolName
                )
                .frame(width: width, height: cardHeight)

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TypeBadge(projectType: projectType)
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(subtitle)
                        .font(CVFont.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    CVProgressBar(fraction: progressFraction, height: 4)
                }
                .padding(CVSpacing.sm)
            }
            .frame(width: width, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)

            Text(title)
                .font(CVFont.cardTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}
