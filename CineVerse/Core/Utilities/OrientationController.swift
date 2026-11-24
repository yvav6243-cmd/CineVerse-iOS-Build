import UIKit
import Observation

@MainActor
@Observable
public final class OrientationController {
    public static let shared = OrientationController()

    public private(set) var mask: UIInterfaceOrientationMask = .portrait

    private init() {}

    public func setAllowedOrientations(_ newMask: UIInterfaceOrientationMask, requestOrientation: UIInterfaceOrientationMask? = nil) {
        mask = newMask
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        let target = requestOrientation ?? newMask
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { error in
            CVLogger.player.error("Geometry orientation update error: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func toggleLandscape() {
        let isCurrentlyLandscape = mask.contains(.landscapeLeft) && !mask.contains(.portrait)
        if isCurrentlyLandscape {
            setAllowedOrientations(.allButUpsideDown, requestOrientation: .portrait)
        } else {
            setAllowedOrientations(.allButUpsideDown, requestOrientation: .landscapeRight)
        }
    }
}
