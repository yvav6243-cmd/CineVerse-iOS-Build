import UIKit

@MainActor
public enum Haptics {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    public static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
