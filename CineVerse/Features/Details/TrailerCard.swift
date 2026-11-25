import SwiftUI

public struct TrailerCard: View {
    let trailerURL: URL?
    let backdropURL: URL?
    let title: String
    @Binding var pendingExternalURL: URL?

    public init(
        trailerURL: URL?,
        backdropURL: URL?,
        title: String,
        pendingExternalURL: Binding<URL?>
    ) {
        self.trailerURL = trailerURL
        self.backdropURL = backdropURL
        self.title = title
        self._pendingExternalURL = pendingExternalURL
    }

    public var body: some View {
        if let trailerURL, trailerURL.scheme?.lowercased() == "https" {
            VStack(alignment: .leading, spacing: CVSpacing.sm) {
                SectionHeader(
                    title: "Trailer",
                    symbolName: "film",
                    actionTitle: nil
                )

                Button {
                    Haptics.impact(.light)
                    pendingExternalURL = trailerURL
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(
                            url: backdropURL,
                            targetSize: CGSize(width: 720, height: 405),
                            fallbackSymbol: "play.rectangle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 148)
                        .clipped()

                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.35),
                                Color.black.opacity(0.80)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .cvGlass(Circle(), interactive: true)
                                Spacer()
                            }
                            Spacer()
                        }

                        HStack(spacing: CVSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Watch Trailer")
                                    .font(CVFont.cardTitle)
                                    .foregroundStyle(.white)
                                Text("\(title) • CineVerse Player")
                                    .font(CVFont.caption)
                                    .foregroundStyle(.white.opacity(0.84))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "play.tv.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(Color.white.opacity(0.20), in: Circle())
                        }
                        .padding(CVSpacing.sm)
                    }
                    .frame(height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }
}
