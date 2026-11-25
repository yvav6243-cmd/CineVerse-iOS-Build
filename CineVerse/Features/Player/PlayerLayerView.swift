import SwiftUI
import AVFoundation
import UIKit

public final class PlayerLayerContainerUIView: UIView {
    public let playerLayer = AVPlayerLayer()
    public var scalingMode: VideoScalingMode = .fit {
        didSet {
            if scalingMode != oldValue {
                updateLayerGravityAndLayout()
            }
        }
    }
    public var presentationSize: CGSize = .zero {
        didSet {
            if presentationSize != oldValue {
                setNeedsLayout()
            }
        }
    }

    private var isConfigured = false

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        configureIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        configureIfNeeded()
        updateLayerGravityAndLayout()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        backgroundColor = .black
        clipsToBounds = true
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    private func updateLayerGravityAndLayout() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.videoGravity = (scalingMode == .fill) ? .resizeAspectFill : .resizeAspect
        let scale = window?.screen.scale ?? max(traitCollection.displayScale, 1.0)
        playerLayer.frame = VideoScalingCalculator.targetFrame(
            containerSize: bounds.size,
            videoSize: presentationSize,
            displayScale: scale,
            mode: scalingMode
        )
        CATransaction.commit()
    }
}

public struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let scalingMode: VideoScalingMode
    let presentationSize: CGSize
    let onLayerReady: (AVPlayerLayer) -> Void

    public init(
        player: AVPlayer,
        scalingMode: VideoScalingMode = .fit,
        presentationSize: CGSize = .zero,
        onLayerReady: @escaping (AVPlayerLayer) -> Void
    ) {
        self.player = player
        self.scalingMode = scalingMode
        self.presentationSize = presentationSize
        self.onLayerReady = onLayerReady
    }

    public func makeUIView(context: Context) -> PlayerLayerContainerUIView {
        let view = PlayerLayerContainerUIView()
        view.playerLayer.player = player
        view.scalingMode = scalingMode
        view.presentationSize = presentationSize
        DispatchQueue.main.async {
            onLayerReady(view.playerLayer)
        }
        return view
    }

    public func updateUIView(_ uiView: PlayerLayerContainerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        if uiView.scalingMode != scalingMode {
            uiView.scalingMode = scalingMode
        }
        if uiView.presentationSize != presentationSize {
            uiView.presentationSize = presentationSize
        }
    }
}
