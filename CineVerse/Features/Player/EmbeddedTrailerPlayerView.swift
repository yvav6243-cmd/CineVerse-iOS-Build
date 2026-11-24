import SwiftUI
import WebKit

public struct EmbeddedTrailerItem: Identifiable, Sendable {
    public let id = UUID()
    public let videoID: String
    public let title: String

    public init(videoID: String, title: String) {
        self.videoID = videoID
        self.title = title
    }

    public static func youTubeID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            let candidate = url.pathComponents.dropFirst().first
            return sanitizeVideoID(candidate)
        }

        if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            if let vQuery = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                return sanitizeVideoID(vQuery)
            }
            let path = url.pathComponents.filter { $0 != "/" }
            if let markerIndex = path.firstIndex(where: { $0 == "embed" || $0 == "shorts" || $0 == "live" }),
               path.index(after: markerIndex) < path.endIndex {
                return sanitizeVideoID(path[path.index(after: markerIndex)])
            }
        }

        return nil
    }

    private static func sanitizeVideoID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 32 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return trimmed
    }
}

public struct EmbeddedTrailerPlayerView: View {
    let item: EmbeddedTrailerItem
    @Environment(\.dismiss) private var dismiss

    public init(item: EmbeddedTrailerItem) {
        self.item = item
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                YouTubeEmbedWebView(videoID: item.videoID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationController.shared.setAllowedOrientations(.allButUpsideDown)
        }
        .onDisappear {
            OrientationController.shared.setAllowedOrientations(.portrait, requestOrientation: .portrait)
        }
    }

    private var topBar: some View {
        HStack(spacing: CVSpacing.md) {
            Button {
                Haptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .cvGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Trailer")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(CVFont.cardTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Official Trailer · CineVerse Player")
                    .font(CVFont.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, CVSpacing.md)
        .padding(.vertical, CVSpacing.sm)
        .background(Color.black.opacity(0.85))
    }
}

private struct YouTubeEmbedWebView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        loadEmbedHTML(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func loadEmbedHTML(in webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
        iframe { position: fixed; inset: 0; width: 100%; height: 100%; border: 0; background: #000; }
        </style>
        </head>
        <body>
        <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=1&rel=0&modestbranding=1"
                allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                allowfullscreen></iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://cineverse.app"))
    }
}
