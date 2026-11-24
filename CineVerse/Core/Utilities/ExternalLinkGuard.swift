import SwiftUI

public struct ExternalLinkConfirmationModifier: ViewModifier {
    @Binding var pendingURL: URL?
    @Environment(\.openURL) private var openURL

    public func body(content: Content) -> some View {
        let isPresented = Binding<Bool>(
            get: { pendingURL != nil },
            set: { newValue in
                if !newValue { pendingURL = nil }
            }
        )

        content
            .confirmationDialog(
                "Open External Link",
                isPresented: isPresented,
                titleVisibility: .visible
            ) {
                if let url = pendingURL, url.scheme?.lowercased() == "https" {
                    Button("Open \(url.host ?? "Website")") {
                        openURL(url)
                        pendingURL = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingURL = nil
                }
            } message: {
                if let url = pendingURL {
                    if url.scheme?.lowercased() == "https" {
                        Text("You are leaving CineVerse to open \(url.host ?? url.absoluteString) in Safari or its official app.")
                    } else {
                        Text("This external link uses an unsupported scheme and cannot be opened.")
                    }
                }
            }
    }
}

public extension View {
    func cvExternalLinkConfirmation(pendingURL: Binding<URL?>) -> some View {
        modifier(ExternalLinkConfirmationModifier(pendingURL: pendingURL))
    }
}
