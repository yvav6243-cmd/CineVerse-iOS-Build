import SwiftUI
import UIKit

public struct CachedAsyncImage: View {
    let url: URL?
    let targetSize: CGSize
    var contentMode: ContentMode = .fill
    var fallbackSymbol: String = "film"

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = false
    @Environment(\.displayScale) private var displayScale

    public init(
        url: URL?,
        targetSize: CGSize = CGSize(width: 300, height: 450),
        contentMode: ContentMode = .fill,
        fallbackSymbol: String = "film"
    ) {
        self.url = url
        self.targetSize = targetSize
        self.contentMode = contentMode
        self.fallbackSymbol = fallbackSymbol
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .cvShimmer(isLoading)

            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            } else if !isLoading {
                Image(systemName: fallbackSymbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            loadedImage = nil
            isLoading = false
            return
        }
        isLoading = true
        let image = await ImagePipeline.shared.image(
            for: url,
            targetSize: targetSize,
            scale: displayScale
        )
        if !Task.isCancelled {
            loadedImage = image
            isLoading = false
        }
    }
}
