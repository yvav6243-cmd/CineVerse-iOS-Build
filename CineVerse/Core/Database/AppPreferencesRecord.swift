import Foundation
import SwiftData
import SwiftUI

public enum AppThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Model
public final class AppPreferencesRecord {
    @Attribute(.unique) public var singletonKey: String
    public var profileName: String
    @Attribute(.externalStorage) public var avatarData: Data?
    public var themeRaw: String
    public var contentLanguageCode: String
    public var defaultAudioLanguage: String
    public var defaultSubtitleLanguage: String
    public var defaultQualityRaw: String
    public var autoplayNext: Bool
    public var autosaveProgress: Bool
    public var episodeAlertsEnabled: Bool
    public var homeSectionsData: Data
    public var subtitleStyleData: Data
    public var watchRegion: String

    public init(
        singletonKey: String = "main",
        profileName: String = "Cinephile",
        avatarData: Data? = nil,
        theme: AppThemePreference = .system,
        contentLanguageCode: String = Locale.preferredLanguages.first ?? "en-US",
        defaultAudioLanguage: String = "en",
        defaultSubtitleLanguage: String = "off",
        defaultQuality: VideoQualityTier = .auto,
        autoplayNext: Bool = true,
        autosaveProgress: Bool = true,
        episodeAlertsEnabled: Bool = false,
        homeSections: [HomeSectionConfiguration] = HomeSectionConfiguration.defaultConfigurations,
        subtitleStyle: SubtitleAppearanceStyle = SubtitleAppearanceStyle(),
        watchRegion: String = Locale.current.region?.identifier ?? "US"
    ) {
        self.singletonKey = singletonKey
        self.profileName = profileName
        self.avatarData = avatarData
        self.themeRaw = theme.rawValue
        self.contentLanguageCode = contentLanguageCode
        self.defaultAudioLanguage = defaultAudioLanguage
        self.defaultSubtitleLanguage = defaultSubtitleLanguage
        self.defaultQualityRaw = defaultQuality.rawValue
        self.autoplayNext = autoplayNext
        self.autosaveProgress = autosaveProgress
        self.episodeAlertsEnabled = episodeAlertsEnabled
        self.homeSectionsData = (try? JSONEncoder().encode(homeSections)) ?? Data()
        self.subtitleStyleData = (try? JSONEncoder().encode(subtitleStyle)) ?? Data()
        self.watchRegion = watchRegion
    }

    public var theme: AppThemePreference {
        get { AppThemePreference(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    public var defaultQuality: VideoQualityTier {
        get { VideoQualityTier(rawValue: defaultQualityRaw) ?? .auto }
        set { defaultQualityRaw = newValue.rawValue }
    }

    public var homeSections: [HomeSectionConfiguration] {
        get {
            let decoded = (try? JSONDecoder().decode([HomeSectionConfiguration].self, from: homeSectionsData))
            if let decoded, !decoded.isEmpty {
                return decoded.sorted { $0.sortOrder < $1.sortOrder }
            }
            return HomeSectionConfiguration.defaultConfigurations
        }
        set {
            homeSectionsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public var subtitleStyle: SubtitleAppearanceStyle {
        get {
            (try? JSONDecoder().decode(SubtitleAppearanceStyle.self, from: subtitleStyleData))
                ?? SubtitleAppearanceStyle()
        }
        set {
            subtitleStyleData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public func toDTO() -> AppPreferencesDTO {
        AppPreferencesDTO(
            profileName: profileName,
            themeRaw: themeRaw,
            contentLanguageCode: contentLanguageCode,
            defaultAudioLanguage: defaultAudioLanguage,
            defaultSubtitleLanguage: defaultSubtitleLanguage,
            defaultQualityRaw: defaultQualityRaw,
            autoplayNext: autoplayNext,
            autosaveProgress: autosaveProgress,
            episodeAlertsEnabled: episodeAlertsEnabled,
            homeSections: homeSections,
            subtitleStyle: subtitleStyle,
            watchRegion: watchRegion
        )
    }
}
