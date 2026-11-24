import SwiftUI

public struct PlaybackScrubber: View {
    let currentTime: TimeInterval
    let bufferedTime: TimeInterval
    let duration: TimeInterval
    let onEditingChanged: (Bool) -> Void
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging: Bool = false
    @State private var dragFraction: Double = 0

    public init(
        currentTime: TimeInterval,
        bufferedTime: TimeInterval,
        duration: TimeInterval,
        onEditingChanged: @escaping (Bool) -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.currentTime = currentTime
        self.bufferedTime = bufferedTime
        self.duration = duration
        self.onEditingChanged = onEditingChanged
        self.onSeek = onSeek
    }

    private var activeFraction: Double {
        if isDragging { return dragFraction }
        guard duration > 0.1 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    private var bufferedFraction: Double {
        guard duration > 0.1 else { return 0 }
        return min(max(bufferedTime / duration, 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let thumbX = width * activeFraction

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(height: isDragging ? 7 : 5)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.38))
                    .frame(width: width * bufferedFraction, height: isDragging ? 7 : 5)

                Capsule(style: .continuous)
                    .fill(CVColor.iris)
                    .frame(width: max(thumbX, 0), height: isDragging ? 7 : 5)

                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 18 : 13, height: isDragging ? 18 : 13)
                    .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 2)
                    .offset(x: min(max(thumbX - (isDragging ? 9 : 6.5), 0), width - (isDragging ? 18 : 13)))
            }
            .frame(height: 32)
            .overlay(alignment: .topLeading) {
                if isDragging && duration > 0.1 {
                    let previewTime = dragFraction * duration
                    Text(previewTime.formattedPlaybackTime)
                        .font(CVFont.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .cvGlass(Capsule(style: .continuous))
                        .offset(
                            x: min(max(thumbX - 28, 0), max(width - 56, 0)),
                            y: -34
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                            Haptics.impact(.light)
                        }
                        dragFraction = min(max(value.location.x / width, 0), 1)
                    }
                    .onEnded { value in
                        let finalFraction = min(max(value.location.x / width, 0), 1)
                        dragFraction = finalFraction
                        isDragging = false
                        onEditingChanged(false)
                        if duration > 0.1 {
                            onSeek(finalFraction * duration)
                        }
                        Haptics.impact(.light)
                    }
            )
            .animation(CVMotion.snappy, value: isDragging)
        }
        .frame(height: 32)
    }
}
