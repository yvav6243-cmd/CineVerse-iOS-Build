import Foundation

public final class OfficialServicesProvider: VideoSourceProvider, @unchecked Sendable {
    public let id = "official_services"
    public let displayName = "Official Streaming Platforms"

    public init() {}

    public func sources(for item: MediaItem, episode: MediaEpisode?) async -> [VideoSourceDescriptor] {
        item.officialPlatformLinks.compactMap { link in
            guard link.url.scheme?.lowercased() == "https" else { return nil }
            return VideoSourceDescriptor(
                id: "official:\(link.id)",
                providerID: id,
                providerName: link.siteName,
                sourceDescription: "Licensed stream available externally on \(link.siteName)",
                isAvailable: true,
                format: .externalOfficialService,
                playbackURL: nil,
                officialServiceURL: link.url,
                episodeID: episode?.id
            )
        }
    }
}
