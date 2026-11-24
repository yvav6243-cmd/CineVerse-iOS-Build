import SwiftUI

public struct CVGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?

    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(configuredGlass, in: shape)
        } else {
            fallbackBody(content: content)
        }
        #else
        fallbackBody(content: content)
        #endif
    }

    private func fallbackBody(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(
                shape.strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.14)
                        : Color.black.opacity(0.08),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                radius: 12,
                x: 0,
                y: 6
            )
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var configuredGlass: Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
    #endif
}

public struct CVShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = -1.0

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.7)
                        .offset(x: phase * proxy.size.width * 1.4)
                    }
                    .clipped()
                    .onAppear {
                        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
            }
    }
}

public extension View {
    func cvGlass<S: Shape>(
        _ shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(CVGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }

    func cvGlass(
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        cvGlass(
            RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous),
            interactive: interactive,
            tint: tint
        )
    }

    func cvCardBackground(cornerRadius: CGFloat = CVRadius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: shape)
            .overlay(
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    func cvShimmer(_ isActive: Bool = true) -> some View {
        modifier(CVShimmerModifier(isActive: isActive))
    }
}
