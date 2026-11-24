import Foundation

public protocol VideoSourceProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor]
}
