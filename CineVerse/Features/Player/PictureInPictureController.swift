import Foundation
import AVKit
import Observation

@MainActor
@Observable
public final class PictureInPictureController: NSObject, AVPictureInPictureControllerDelegate {
    public var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    public private(set) var isActive: Bool = false
    private var pipController: AVPictureInPictureController?
    private var onRestoreUI: (() -> Void)?

    public override init() {
        super.init()
    }

    public func attach(to playerLayer: AVPlayerLayer, onRestoreUI: (() -> Void)? = nil) {
        self.onRestoreUI = onRestoreUI
        guard isSupported else { return }
        if pipController?.playerLayer === playerLayer { return }

        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self
        self.pipController = controller
    }

    public func toggle() {
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        }
    }

    public func detach() {
        pipController?.delegate = nil
        pipController = nil
        isActive = false
    }

    nonisolated public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = true
        }
    }

    nonisolated public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isActive = false
        }
    }

    nonisolated public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.onRestoreUI?()
            completionHandler(true)
        }
    }
}
