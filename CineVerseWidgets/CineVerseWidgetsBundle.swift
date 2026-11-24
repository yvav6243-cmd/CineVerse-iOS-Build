import SwiftUI
import WidgetKit

@main
public struct CineVerseWidgetsBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        ContinueWatchingWidget()
        UpcomingEpisodesWidget()
        PlaybackLiveActivity()
    }
}
