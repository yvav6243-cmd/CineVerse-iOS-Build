import SwiftUI

public struct AmbientBackground: View {
    let artworkURL: URL?
    let palette: ArtworkPalette

    @Environment(\.colorScheme) private var colorScheme

    public init(artworkURL: URL?, palette: ArtworkPalette = .default) {
        self.artworkURL = artworkURL
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            Color(.systemBackground)

            if let artworkURL {
                CachedAsyncImage(
                    url: artworkURL,
                    targetSize: CGSize(width: 200, height: 300),
                    fallbackSymbol: "film"
                )
                .blur(radius: 60)
                .opacity(colorScheme == .dark ? 0.42 : 0.22)
                .scaleEffect(1.25)
            }

            palette.primaryColor
                .opacity(colorScheme == .dark ? 0.16 : 0.08)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(.systemBackground).opacity(0.65),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
