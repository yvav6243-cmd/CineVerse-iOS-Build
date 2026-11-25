import SwiftUI

public struct PlayerSettingsSheet: View {
    let session: PlayerSession
    let settingsStore: SettingsStore
    let onImportSubtitle: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    public init(
        session: PlayerSession,
        settingsStore: SettingsStore,
        onImportSubtitle: @escaping () -> Void
    ) {
        self.session = session
        self.settingsStore = settingsStore
        self.onImportSubtitle = onImportSubtitle
    }

    public var body: some View {
        NavigationStack {
            List {
                if !session.alternativeSources.isEmpty {
                    Section {
                        ForEach(session.alternativeSources) { src in
                            Button {
                                Haptics.selection()
                                Task { await session.switchSource(to: src) }
                            } label: {
                                HStack(spacing: CVSpacing.sm) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(src.providerName)
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(src.highestQualityLabel)
                                                .font(CVFont.micro.weight(.bold))
                                                .foregroundStyle(CVColor.amber)
                                        }
                                        Text("\(src.healthStatus.badgeLabel) · \(src.audioSummaryLabel) · \(src.subtitleSummaryLabel)")
                                            .font(CVFont.micro)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(src.format.badgeText)
                                        .font(CVFont.micro)
                                        .foregroundStyle(CVColor.iris)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(CVColor.iris.opacity(0.14), in: Capsule(style: .continuous))
                                    if src.id == session.selection.source.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(CVColor.iris)
                                    }
                                }
                            }
                            .disabled(session.isSwitchingSource)
                        }
                    } header: {
                        HStack {
                            Text("Verified Video Sources")
                            Spacer()
                            if session.isSwitchingSource {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                }

                Section {
                    if session.engine.availableQualities.isEmpty {
                        Text("Automatic adaptive quality")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.engine.availableQualities) { quality in
                            Button {
                                session.selectQuality(quality)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(quality.detailedLabel)
                                            .foregroundStyle(.primary)
                                        if let dims = quality.resolutionDimensionsText {
                                            Text(dims)
                                                .font(CVFont.micro)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if session.engine.selectedQuality?.id == quality.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(CVColor.iris)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Video Quality (2K / 4K Priority)")
                        Spacer()
                        Text(session.engine.diagnostics.compactSummary)
                            .font(CVFont.micro)
                            .foregroundStyle(CVColor.iris)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Real Decoded Output: \(session.engine.diagnostics.fullTechnicalSummary)")
                        if let limitNote = session.sourceQualityLimitationNote {
                            Text(limitNote)
                                .foregroundStyle(CVColor.warning)
                        }
                    }
                    .font(CVFont.micro)
                }

                Section("Audio Track & Voiceover") {
                    if session.engine.availableAudioTracks.isEmpty {
                        Text("Original audio track")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.engine.availableAudioTracks) { track in
                            Button {
                                session.selectAudio(track)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.fullLabel)
                                            .foregroundStyle(.primary)
                                        Text("\(LanguageCatalog.displayName(forLanguageCode: track.languageCode)) · \(track.voiceoverKind.rawValue)")
                                            .font(CVFont.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if session.engine.selectedAudioTrack?.id == track.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(CVColor.iris)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Subtitles") {
                    Button {
                        session.selectSubtitle(nil)
                    } label: {
                        HStack {
                            Text("Off")
                                .foregroundStyle(.primary)
                            Spacer()
                            if session.engine.selectedSubtitleTrack == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(CVColor.iris)
                            }
                        }
                    }

                    ForEach(session.engine.availableSubtitles) { sub in
                        Button {
                            session.selectSubtitle(sub)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.displayName)
                                        .foregroundStyle(.primary)
                                    Text(sub.format.rawValue)
                                        .font(CVFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if session.engine.selectedSubtitleTrack?.id == sub.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CVColor.iris)
                                }
                            }
                        }
                    }

                    if !session.subtitleEngine.cues.isEmpty {
                        HStack {
                            Text("Sync Offset")
                            Spacer()
                            Button("-0.25s") {
                                Haptics.selection()
                                session.subtitleEngine.adjustTimingOffset(by: -0.25, currentVideoTime: session.engine.currentTime)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Text(String(format: "%+.2fs", session.subtitleEngine.timingOffsetSeconds))
                                .font(CVFont.caption.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 52)

                            Button("+0.25s") {
                                Haptics.selection()
                                session.subtitleEngine.adjustTimingOffset(by: 0.25, currentVideoTime: session.engine.currentTime)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if session.subtitleEngine.timingOffsetSeconds != 0 {
                                Button("Reset") {
                                    Haptics.selection()
                                    session.subtitleEngine.resetTimingOffset(currentVideoTime: session.engine.currentTime)
                                }
                                .font(CVFont.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Button {
                        dismiss()
                        onImportSubtitle()
                    } label: {
                        Label("Import External Subtitle (.srt / .vtt)", systemImage: "doc.badge.plus")
                    }

                    NavigationLink {
                        SubtitleStyleSettingsView(settingsStore: settingsStore)
                    } label: {
                        Label("Subtitle Appearance", systemImage: "textformat.size")
                    }
                }

                Section("Playback Speed") {
                    ForEach(rates, id: \.self) { rate in
                        Button {
                            session.engine.setRate(rate)
                        } label: {
                            HStack {
                                Text(rate == 1.0 ? "1x (Normal)" : String(format: "%.2gx", rate))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if session.engine.playbackRate == rate {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CVColor.iris)
                                }
                            }
                        }
                    }
                }

                Section("Picture Enhancement") {
                    ForEach(VideoPicturePreset.allCases) { preset in
                        Button {
                            Haptics.selection()
                            session.picturePreset = preset
                        } label: {
                            HStack(spacing: CVSpacing.sm) {
                                Image(systemName: preset.symbolName)
                                    .foregroundStyle(CVColor.iris)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.rawValue)
                                        .foregroundStyle(.primary)
                                    Text(preset.subtitle)
                                        .font(CVFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if session.picturePreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(CVColor.iris)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playback Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
