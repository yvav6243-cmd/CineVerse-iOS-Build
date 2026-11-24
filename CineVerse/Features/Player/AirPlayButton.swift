import SwiftUI
import AVKit

public struct AirPlayButton: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = UIColor(CVColor.iris)
        view.prioritizesVideoDevices = true
        return view
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
