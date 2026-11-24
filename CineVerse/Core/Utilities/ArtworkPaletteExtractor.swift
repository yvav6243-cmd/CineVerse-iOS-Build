import UIKit
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

public struct ArtworkPalette: Hashable, Sendable {
    public let primaryHex: String
    public let secondaryHex: String
    public let isDark: Bool

    public var primaryColor: Color { Color(hex: primaryHex) }
    public var secondaryColor: Color { Color(hex: secondaryHex) }

    public static let `default` = ArtworkPalette(
        primaryHex: "#6E5BFF",
        secondaryHex: "#1C1A33",
        isDark: true
    )
}

public actor ArtworkPaletteExtractor {
    public static let shared = ArtworkPaletteExtractor()

    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    private var cache: [String: ArtworkPalette] = [:]

    public init() {}

    public func palette(for url: URL?) async -> ArtworkPalette {
        guard let url else { return .default }
        let key = url.absoluteString
        if let cached = cache[key] {
            return cached
        }

        guard let image = await ImagePipeline.shared.image(
            for: url,
            targetSize: CGSize(width: 40, height: 40),
            scale: 1
        ),
        let cgImage = image.cgImage else {
            return .default
        }

        let extracted = computePalette(from: cgImage)
        cache[key] = extracted
        return extracted
    }

    private func computePalette(from cgImage: CGImage) -> ArtworkPalette {
        let inputImage = CIImage(cgImage: cgImage)
        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = inputImage.extent

        guard let outputImage = filter.outputImage else {
            return .default
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let primaryHex = String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
        let secondaryR = UInt8(max(0, min(255, Int(Double(bitmap[0]) * 0.45))))
        let secondaryG = UInt8(max(0, min(255, Int(Double(bitmap[1]) * 0.45))))
        let secondaryB = UInt8(max(0, min(255, Int(Double(bitmap[2]) * 0.45))))
        let secondaryHex = String(format: "#%02X%02X%02X", secondaryR, secondaryG, secondaryB)

        return ArtworkPalette(
            primaryHex: primaryHex,
            secondaryHex: secondaryHex,
            isDark: luminance < 0.55
        )
    }
}
