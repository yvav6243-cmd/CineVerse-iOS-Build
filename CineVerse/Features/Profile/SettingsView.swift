import SwiftUI
import UIKit

public struct SettingsView: View {
    let settingsStore: SettingsStore
    let alertScheduler: EpisodeAlertScheduler

    @Environment(\.openURL) private var openURL
    @State private var showNotificationPermissionAlert: Bool = false

    public init(settingsStore: SettingsStore, alertScheduler: EpisodeAlertScheduler) {
        self.settingsStore = settingsStore
        self.alertScheduler = alertScheduler
    }

    private var metadataLanguageOptions: [LanguageOption] {
        let list = LanguageCatalog.contentMetadataLanguages
        let current = settingsStore.contentLanguageCode
        if list.contains(where: { $0.code == current }) {
            return list
        }
        let fallbackName = LanguageCatalog.displayName(forLanguageCode: current)
        return [LanguageOption(code: current, name: fallbackName)] + list
    }

    private var voiceoverLanguageOptions: [LanguageOption] {
        let list = LanguageCatalog.audioAndSubtitleLanguages
        let current = settingsStore.defaultAudioLanguage
        if list.contains(where: { $0.code == current }) {
            return list
        }
        let fallbackName = LanguageCatalog.displayName(forLanguageCode: current)
        return [LanguageOption(code: current, name: fallbackName)] + list
    }

    private var subtitleLanguageOptions: [LanguageOption] {
        let offOption = LanguageOption(code: "off", name: "Off")
        let list = [offOption] + LanguageCatalog.audioAndSubtitleLanguages
        let current = settingsStore.defaultSubtitleLanguage
        if list.contains(where: { $0.code == current }) {
            return list
        }
        let fallbackName = LanguageCatalog.displayName(forLanguageCode: current)
        return [offOption, LanguageOption(code: current, name: fallbackName)] + LanguageCatalog.audioAndSubtitleLanguages
    }

    private var regionOptions: [CountryOption] {
        let list = LanguageCatalog.countries
        let current = settingsStore.watchRegion
        if list.contains(where: { $0.code == current }) {
            return list
        }
        let name = Locale.current.localizedString(forRegionCode: current) ?? current
        return [CountryOption(code: current, name: name)] + list
    }

    public var body: some View {
        @Bindable var store = settingsStore

        Form {
            Section("Appearance & Language") {
                Picker("Theme", selection: $store.theme) {
                    ForEach(AppThemePreference.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Label("App Language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(Locale.current.language.languageCode?.identifier.uppercased() ?? "System")
                            .font(CVFont.callout)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("Catalog & Region") {
                Picker("Content Metadata Language", selection: $store.contentLanguageCode) {
                    ForEach(metadataLanguageOptions) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                Picker("Watch Region", selection: $store.watchRegion) {
                    ForEach(regionOptions) { country in
                        Text(country.name).tag(country.code)
                    }
                }
            }

            Section("Playback Defaults") {
                Picker("Default Voiceover Language", selection: $store.defaultAudioLanguage) {
                    ForEach(voiceoverLanguageOptions) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                Picker("Default Subtitles", selection: $store.defaultSubtitleLanguage) {
                    ForEach(subtitleLanguageOptions) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                Picker("Default Video Quality", selection: $store.defaultQuality) {
                    ForEach(VideoQualityTier.allCases) { tier in
                        Text(tier.displayLabel).tag(tier)
                    }
                }

                Toggle("Autoplay Next Episode", isOn: $store.autoplayNext)
                Toggle("Autosave Watch Progress", isOn: $store.autosaveProgress)

                NavigationLink {
                    SubtitleStyleSettingsView(settingsStore: settingsStore)
                } label: {
                    Label("Subtitle Appearance", systemImage: "textformat.size")
                }
            }

            Section {
                Toggle("Episode Airing Alerts", isOn: Binding(
                    get: { store.episodeAlertsEnabled },
                    set: { newValue in
                        Task {
                            await handleEpisodeAlertsToggle(newValue)
                        }
                    }
                ))
            } header: {
                Text("Notifications")
            } footer: {
                Text("Receive local notifications when new episodes air for shows and anime in your active list.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications Permission Required", isPresented: $showNotificationPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for CineVerse in iOS Settings to enable episode alerts.")
        }
    }

    private func handleEpisodeAlertsToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await alertScheduler.requestAuthorization()
            if granted {
                settingsStore.episodeAlertsEnabled = true
                await alertScheduler.syncScheduledAlerts()
            } else {
                settingsStore.episodeAlertsEnabled = false
                showNotificationPermissionAlert = true
            }
        } else {
            settingsStore.episodeAlertsEnabled = false
            await alertScheduler.syncScheduledAlerts()
        }
    }
}
