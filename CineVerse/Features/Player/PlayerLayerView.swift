import SwiftUI
import AVFoundation
import UIKit

public final class PlayerLayerContainerUIView: UIView {
    public override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    public var playerLayer: AVPlayerLayer {
        (layer as? AVPlayerLayer) ?? AVPlayerLayer()
    }
}

public struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity
    let onLayerReady: (AVPlayerLayer) -> Void

    public init(
        player: AVPlayer,
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        onLayerReady: @escaping (AVPlayerLayer) -> Void
    ) {
        self.player = player
        self.videoGravity = videoGravity
        self.onLayerReady = onLayerReady
    }

    public func makeUIView(context: Context) -> PlayerLayerContainerUIView {
        let view = PlayerLayerContainerUIView()
        view.backgroundColor = .black
        let pLayer = view.playerLayer
        pLayer.player = player
        pLayer.videoGravity = videoGravity
        DispatchQueue.main.async {
            onLayerReady(pLayer)
        }
        return view
    }

    public func updateUIView(_ uiView: PlayerLayerContainerUIView, context: Context) {
        let pLayer = uiView.playerLayer
        if pLayer.player !== player {
            pLayer.player = player
        }
        if pLayer.videoGravity != videoGravity {
            pLayer.videoGravity = videoGravity
        }
    }
}
