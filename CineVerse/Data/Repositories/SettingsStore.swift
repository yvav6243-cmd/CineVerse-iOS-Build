import Foundation
import SwiftData
import Observation

@MainActor
@Observable
public final class SettingsStore {
    private let modelContext: ModelContext
    private var record: AppPreferencesRecord

    public var profileName: String {
        didSet { record.profileName = profileName; save() }
    }
    public var avatarData: Data? {
        didSet { record.avatarData = avatarData; save() }
    }
    public var theme: AppThemePreference {
        didSet { record.theme = theme; save() }
    }
    public var contentLanguageCode: String {
        didSet { record.contentLanguageCode = contentLanguageCode; save() }
    }
    public var defaultAudioLanguage: String {
        didSet { record.defaultAudioLanguage = defaultAudioLanguage; save() }
    }
    public var defaultSubtitleLanguage: String {
        didSet { record.defaultSubtitleLanguage = defaultSubtitleLanguage; save() }
    }
    public var defaultQuality: VideoQualityTier {
        didSet { record.defaultQuality = defaultQuality; save() }
    }
    public var autoplayNext: Bool {
        didSet { record.autoplayNext = autoplayNext; save() }
    }
    public var autosaveProgress: Bool {
        didSet { record.autosaveProgress = autosaveProgress; save() }
    }
    public var episodeAlertsEnabled: Bool {
        didSet { record.episodeAlertsEnabled = episodeAlertsEnabled; save() }
    }
    public var homeSections: [HomeSectionConfiguration] {
        didSet { record.homeSections = homeSections; save() }
    }
    public var subtitleStyle: SubtitleAppearanceStyle {
        didSet { record.subtitleStyle = subtitleStyle; save() }
    }
    public var watchRegion: String {
        didSet { record.watchRegion = watchRegion; save() }
    }
    public var audioLanguagePriority: [String] {
        didSet { record.audioLanguagePriority = audioLanguagePriority; save() }
    }
    public var preferredGenres: [String] {
        didSet { record.preferredGenres = preferredGenres; save() }
    }
    public var gestureSensitivity: Double {
        didSet {
            let clamped = min(max(gestureSensitivity, 0.5), 2.0)
            record.gestureSensitivity = clamped
            save()
        }
    }

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let loaded = Self.fetchOrCreateRecord(in: modelContext)
        self.record = loaded
        self.profileName = loaded.profileName
        self.avatarData = loaded.avatarData
        self.theme = loaded.theme
        self.contentLanguageCode = loaded.contentLanguageCode
        self.defaultAudioLanguage = loaded.defaultAudioLanguage
        self.defaultSubtitleLanguage = loaded.defaultSubtitleLanguage
        self.defaultQuality = loaded.defaultQuality
        self.autoplayNext = loaded.autoplayNext
        self.autosaveProgress = loaded.autosaveProgress
        self.episodeAlertsEnabled = loaded.episodeAlertsEnabled
        self.homeSections = Self.normalizedHomeSections(loaded.homeSections)
        self.subtitleStyle = loaded.subtitleStyle
        self.watchRegion = loaded.watchRegion
        self.audioLanguagePriority = loaded.audioLanguagePriority
        self.preferredGenres = loaded.preferredGenres
        self.gestureSensitivity = loaded.gestureSensitivity > 0 ? loaded.gestureSensitivity : 1.0
    }

    public func reloadFromDatabase() {
        let loaded = Self.fetchOrCreateRecord(in: modelContext)
        record = loaded
        profileName = loaded.profileName
        avatarData = loaded.avatarData
        theme = loaded.theme
        contentLanguageCode = loaded.contentLanguageCode
        defaultAudioLanguage = loaded.defaultAudioLanguage
        defaultSubtitleLanguage = loaded.defaultSubtitleLanguage
        defaultQuality = loaded.defaultQuality
        autoplayNext = loaded.autoplayNext
        autosaveProgress = loaded.autosaveProgress
        episodeAlertsEnabled = loaded.episodeAlertsEnabled
        homeSections = loaded.homeSections
        subtitleStyle = loaded.subtitleStyle
        watchRegion = loaded.watchRegion
        audioLanguagePriority = loaded.audioLanguagePriority
        preferredGenres = loaded.preferredGenres
        gestureSensitivity = loaded.gestureSensitivity > 0 ? loaded.gestureSensitivity : 1.0
    }

    public func resetHomeSections() {
        homeSections = HomeSectionConfiguration.defaultConfigurations
    }

    public func applyDTO(_ dto: AppPreferencesDTO) {
        profileName = dto.profileName
        theme = AppThemePreference(rawValue: dto.themeRaw) ?? .system
        contentLanguageCode = dto.contentLanguageCode
        defaultAudioLanguage = dto.defaultAudioLanguage
        defaultSubtitleLanguage = dto.defaultSubtitleLanguage
        defaultQuality = VideoQualityTier(rawValue: dto.defaultQualityRaw) ?? .auto
        autoplayNext = dto.autoplayNext
        autosaveProgress = dto.autosaveProgress
        episodeAlertsEnabled = dto.episodeAlertsEnabled
        homeSections = dto.homeSections
        subtitleStyle = dto.subtitleStyle
        watchRegion = dto.watchRegion
    }

    public func exportDTO() -> AppPreferencesDTO {
        record.toDTO()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            CVLogger.database.error("Failed saving preferences: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fetchOrCreateRecord(in context: ModelContext) -> AppPreferencesRecord {
        let descriptor = FetchDescriptor<AppPreferencesRecord>(
            predicate: #Predicate { $0.singletonKey == "main" }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppPreferencesRecord()
        context.insert(created)
        try? context.save()
        return created
    }

    private static func normalizedHomeSections(_ existing: [HomeSectionConfiguration]) -> [HomeSectionConfiguration] {
        guard !existing.isEmpty else { return HomeSectionConfiguration.defaultConfigurations }
        var result = existing
        let present = Set(existing.map(\.section))
        var nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        for section in HomeSectionType.allCases where !present.contains(section) {
            result.append(HomeSectionConfiguration(section: section, isVisible: true, sortOrder: nextOrder))
            nextOrder += 1
        }
        return result
    }
}
