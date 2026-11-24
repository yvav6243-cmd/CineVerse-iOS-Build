import SwiftUI

public extension View {
    @ViewBuilder
    func cvIfAvailableZoomTransition(
        id: String,
        in namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    @ViewBuilder
    func cvMatchedSource(
        id: String,
        in namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
