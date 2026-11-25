import Foundation

public struct ConfigurableSourceProviderInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String

    public init(id: String, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public enum SourceProviderPreferences {
    private static let keyPrefix = "cv_provider_enabled_"

    public static let configurableProviders: [ConfigurableSourceProviderInfo] = [
        ConfigurableSourceProviderInfo(
            id: "open_stream",
            title: "CineVerse Open Cinema (HLS)",
            subtitle: "4K/2K/1080p adaptive HLS open-source cinema & animation"
        ),
        ConfigurableSourceProviderInfo(
            id: "internet_archive",
            title: "Internet Archive",
            subtitle: "Public domain films, classic cartoons, docs & short films"
        ),
        ConfigurableSourceProviderInfo(
            id: "wikimedia_cinema",
            title: "Wikimedia Commons Cinema",
            subtitle: "Restored 4K/1080p public domain films with timed subtitles"
        ),
        ConfigurableSourceProviderInfo(
            id: "peertube_cc",
            title: "PeerTube Creative Commons",
            subtitle: "Independent & festival Creative Commons HLS/MP4 releases"
        ),
        ConfigurableSourceProviderInfo(
            id: "official_services",
            title: "Official Streaming Platforms",
            subtitle: "Licensed regional platform links (opens external web page)"
        )
    ]

    public static func isEnabled(providerID: String) -> Bool {
        if providerID == "local_file" || providerID == "direct_link" {
            return true
        }
        let key = keyPrefix + providerID
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    public static func setEnabled(_ enabled: Bool, for providerID: String) {
        guard providerID != "local_file" && providerID != "direct_link" else { return }
        UserDefaults.standard.set(enabled, forKey: keyPrefix + providerID)
    }
}
