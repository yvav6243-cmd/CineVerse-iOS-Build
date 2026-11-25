import SwiftUI

public enum AddSourceTab: String, CaseIterable, Identifiable, Sendable {
    case link = "HTTPS Link (.m3u8 / .mp4 / .webm)"
    case file = "Local Video File"
    public var id: String { rawValue }
}

public struct PlaybackSetupPanel: View {
    let item: MediaItem
    @Bindable var viewModel: PlaybackSetupViewModel
    let startPositionSeconds: TimeInterval
    let alertsEnabled: Bool
    let onSelectEpisode: (MediaEpisode) -> Void
    let onStartWatching: (PreWatchPlaybackSelection) -> Void
    let onOpenAddSource: (AddSourceTab) -> Void
    let onImportSubtitle: () -> Void
    let onOpenOfficialURL: (URL) -> Void
    let onPlayTrailer: () -> Void
    let onToggleAlerts: () -> Void

    public init(
        item: MediaItem,
        viewModel: PlaybackSetupViewModel,
        startPositionSeconds: TimeInterval,
        alertsEnabled: Bool = false,
        onSelectEpisode: @escaping (MediaEpisode) -> Void,
        onStartWatching: @escaping (PreWatchPlaybackSelection) -> Void,
        onOpenAddSource: @escaping (AddSourceTab) -> Void,
        onImportSubtitle: @escaping () -> Void,
        onOpenOfficialURL: @escaping (URL) -> Void,
        onPlayTrailer: @escaping () -> Void,
        onToggleAlerts: @escaping () -> Void = {}
    ) {
        self.item = item
        self.viewModel = viewModel
        self.startPositionSeconds = startPositionSeconds
        self.alertsEnabled = alertsEnabled
        self.onSelectEpisode = onSelectEpisode
        self.onStartWatching = onStartWatching
        self.onOpenAddSource = onOpenAddSource
        self.onImportSubtitle = onImportSubtitle
        self.onOpenOfficialURL = onOpenOfficialURL
        self.onPlayTrailer = onPlayTrailer
        self.onToggleAlerts = onToggleAlerts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.md) {
            headerRow

            if item.projectType.isEpisodic {
                episodeSelectorRow
            }

            if viewModel.isResolving && !viewModel.hasPlayableSource {
                HStack(spacing: CVSpacing.sm) {
                    ProgressView()
                    Text("Probing full-length video sources, audio tracks, and stream health...")
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, CVSpacing.xs)
            } else if viewModel.hasPlayableSource, let source = viewModel.selectedSource {
                sourceCardsList(selected: source)
                menusSection
                if let error = viewModel.subtitleImportError {
                    Text(error).font(CVFont.caption).foregroundStyle(CVColor.danger)
                }
                startWatchingButton
            } else {
                noPlayableSourceFallback
            }
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: CVSpacing.xs) {
                Image(systemName: "play.tv")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CVColor.iris)
                Text("Video Sources & Voiceovers")
                    .font(CVFont.sectionTitle)
                Spacer()
                if viewModel.isInspecting || viewModel.isResolving {
                    ProgressView().controlSize(.small)
                }
                Button {
                    Haptics.selection()
                    onOpenAddSource(.link)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CVColor.iris)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach custom stream or local file")
            }

            if let summary = viewModel.availabilitySummary {
                HStack(spacing: 6) {
                    AvailabilityBadge(
                        status: summary.status,
                        compact: false,
                        detailText: summary.canWatchInApp ? summary.highestQualityLabel : nil
                    )
                    Spacer(minLength: 4)
                    if summary.canWatchInApp && !summary.audioLanguages.isEmpty {
                        Text(summary.audioLanguages.prefix(2).joined(separator: ", "))
                            .font(CVFont.micro)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var episodeSelectorRow: some View {
        let allEpisodes = item.seasons
            .filter { $0.seasonNumber > 0 }
            .sorted { $0.seasonNumber < $1.seasonNumber }
            .flatMap { $0.episodes.sorted { $0.episodeNumber < $1.episodeNumber } }

        if !allEpisodes.isEmpty {
            Menu {
                ForEach(allEpisodes.prefix(80)) { ep in
                    Button {
                        Haptics.selection()
                        onSelectEpisode(ep)
                    } label: {
                        menuOptionLabel("\(ep.formattedCode) · \(ep.title)", selected: viewModel.selectedEpisode?.id == ep.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.badge.play").font(.caption.weight(.semibold))
                    Text(viewModel.selectedEpisode.map { "Episode: \($0.formattedCode) · \($0.title)" } ?? "Select Episode")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                }
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .padding(.horizontal, CVSpacing.sm)
                .padding(.vertical, 8)
                .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: CVRadius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func sourceCardsList(selected: VideoSourceDescriptor) -> some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            Text("Verified Full-Length Sources (\(viewModel.playableSources.count))")
                .font(CVFont.micro.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(viewModel.playableSources) { src in
                sourceCardRow(src, isSelected: src.id == selected.id)
            }
        }
    }

    private func sourceCardRow(_ src: VideoSourceDescriptor, isSelected: Bool) -> some View {
        let fillColor = isSelected ? CVColor.iris.opacity(0.14) : Color(.tertiarySystemFill).opacity(0.45)
        let borderColor = isSelected ? CVColor.iris.opacity(0.65) : Color.clear
        return Button {
            Haptics.selection()
            Task { await viewModel.selectSource(src) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? CVColor.iris : .secondary)
                    Text(src.providerName)
                        .font(CVFont.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    badgePill(src.highestQualityLabel, tint: CVColor.amber)
                    badgePill(src.format.badgeText, tint: CVColor.iris)
                }

                HStack(spacing: 8) {
                    Label(src.healthStatus.badgeLabel, systemImage: "checkmark.shield.fill")
                        .foregroundStyle(CVColor.success)
                    Text("·")
                    Text(durationText(for: src))
                    Text("·")
                    Text(src.isAvailable ? "Available" : "Offline")
                }
                .font(CVFont.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                HStack(spacing: 8) {
                    Label("Audio: \(src.audioSummaryLabel)", systemImage: "waveform")
                    Text("·")
                    Label("Subs: \(src.subtitleSummaryLabel)", systemImage: "captions.bubble")
                }
                .font(CVFont.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(CVSpacing.sm)
            .background(fillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if viewModel.isUserSource(src) {
                Button(role: .destructive) {
                    Task { await viewModel.deleteSource(src) }
                } label: {
                    Label("Remove Source", systemImage: "trash")
                }
            }
        }
    }

    private func durationText(for src: VideoSourceDescriptor) -> String {
        if let sec = src.durationSeconds, sec >= 60 {
            return "\(Int((sec / 60).rounded())) min"
        }
        let fallbackMin = viewModel.selectedEpisode?.durationMinutes ?? item.durationMinutes
        return fallbackMin > 0 ? "\(fallbackMin) min" : "Full Stream"
    }

    private func badgePill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(CVFont.micro.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.16), in: Capsule(style: .continuous))
    }

    private var menusSection: some View {
        VStack(spacing: 0) {
            qualityMenuRow
            Divider().padding(.leading, 34)
            voiceoverMenuRow
            Divider().padding(.leading, 34)
            subtitlesMenuRow
        }
        .background(Color(.tertiarySystemFill).opacity(0.45), in: RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))
    }

    private var qualityMenuRow: some View {
        Menu {
            if viewModel.availableQualities.isEmpty {
                Text("Automatic")
            } else {
                ForEach(viewModel.availableQualities) { quality in
                    Button {
                        Haptics.selection()
                        viewModel.selectQuality(quality)
                    } label: {
                        menuOptionLabel(quality.detailedLabel, selected: viewModel.selectedQuality?.id == quality.id)
                    }
                }
            }
        } label: {
            setupRowContent(
                icon: "dial.high",
                title: "Quality",
                value: viewModel.selectedQuality?.detailedLabel ?? "Auto (Adaptive)",
                badgeText: viewModel.selectedQuality?.tier.shortBadge,
                badgeTint: CVColor.amber
            )
        }
        .buttonStyle(.plain)
    }

    private var voiceoverMenuRow: some View {
        Menu {
            if viewModel.availableAudioTracks.isEmpty {
                Text("Original Audio")
            } else {
                ForEach(viewModel.availableAudioTracks) { track in
                    Button {
                        Haptics.selection()
                        viewModel.selectAudioTrack(track)
                    } label: {
                        menuOptionLabel(track.fullLabel, selected: viewModel.selectedAudioTrack?.id == track.id)
                    }
                }
            }
        } label: {
            let track = viewModel.selectedAudioTrack
            setupRowContent(
                icon: "waveform",
                title: "Voiceover",
                value: track?.fullLabel ?? "Original Audio",
                badgeText: (track?.isOriginal == true) ? "Original" : track?.voiceoverKind.rawValue,
                badgeTint: CVColor.success
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitlesMenuRow: some View {
        Menu {
            Button {
                Haptics.selection()
                viewModel.selectSubtitleTrack(nil)
            } label: {
                menuOptionLabel("Off", selected: viewModel.selectedSubtitleTrack == nil)
            }
            if !viewModel.availableSubtitles.isEmpty {
                Divider()
                ForEach(viewModel.availableSubtitles) { sub in
                    Button {
                        Haptics.selection()
                        viewModel.selectSubtitleTrack(sub)
                    } label: {
                        menuOptionLabel("\(sub.displayName) (\(sub.format.rawValue))", selected: viewModel.selectedSubtitleTrack?.id == sub.id)
                    }
                }
            }
            Divider()
            Button { onImportSubtitle() } label: {
                Label("Import Subtitle (.srt / .vtt)", systemImage: "doc.badge.plus")
            }
        } label: {
            let subValue = viewModel.selectedSubtitleTrack.map { "\($0.displayName) (\($0.format.rawValue))" } ?? "Off"
            setupRowContent(icon: "captions.bubble", title: "Subtitles", value: subValue)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func menuOptionLabel(_ text: String, selected: Bool) -> some View {
        HStack {
            Text(text)
            if selected { Image(systemName: "checkmark") }
        }
    }

    private func setupRowContent(
        icon: String,
        title: String,
        value: String,
        badgeText: String? = nil,
        badgeTint: Color = CVColor.iris
    ) -> some View {
        HStack(spacing: CVSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .frame(width: 22)
            Text(LocalizedStringKey(title))
                .font(CVFont.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let badgeText {
                badgePill(badgeText, tint: badgeTint)
            }
            Text(value)
                .font(CVFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, CVSpacing.sm)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var startWatchingButton: some View {
        Button {
            Haptics.impact(.medium)
            if let selection = viewModel.buildPlaybackSelection(startPositionSeconds: startPositionSeconds) {
                onStartWatching(selection)
            }
        } label: {
            HStack(spacing: CVSpacing.xs) {
                Image(systemName: "play.fill").font(.subheadline.weight(.bold))
                Text(startPositionSeconds > 5 ? "Watch Full Video · Resume \(startPositionSeconds.formattedPlaybackTime)" : "Watch Full Video")
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CVPrimaryButtonStyle())
        .disabled(viewModel.isInspecting)
    }

    private var noPlayableSourceFallback: some View {
        let status = viewModel.effectiveAvailabilityStatus
        let explanation = viewModel.availabilitySummary?.explanation
            ?? "No verified full-length stream is attached yet. CineVerse never substitutes short trailers for full films."
        return VStack(alignment: .leading, spacing: CVSpacing.sm) {
            HStack(spacing: CVSpacing.sm) {
                Image(systemName: status.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: status.accentHex))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: status.accentHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.rawValue).font(CVFont.cardTitle)
                    Text(explanation)
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let relDate = item.releaseDate, relDate > Date() {
                        Text("Premiere Date: \(CineVerseDateFormatters.mediumDisplay.string(from: relDate))")
                            .font(CVFont.micro.weight(.semibold))
                            .foregroundStyle(CVColor.amber)
                    }
                }
            }

            Button {
                Haptics.selection()
                onToggleAlerts()
            } label: {
                Label(
                    alertsEnabled ? "Availability Alert Enabled" : "Notify Me When Watchable",
                    systemImage: alertsEnabled ? "bell.fill" : "bell.badge"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVGlassButtonStyle(compact: true, tint: alertsEnabled ? CVColor.amber.opacity(0.20) : nil))

            if !viewModel.officialSources.isEmpty {
                Text("External Official Platforms (Opens Web Page)")
                    .font(CVFont.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CVSpacing.xs) {
                        ForEach(viewModel.officialSources) { official in
                            if let url = official.officialServiceURL {
                                Button { Haptics.selection(); onOpenOfficialURL(url) } label: {
                                    Label(official.providerName, systemImage: "arrow.up.right.square")
                                }.buttonStyle(CVGlassButtonStyle(compact: true))
                            }
                        }
                    }
                }
            }

            HStack(spacing: CVSpacing.xs) {
                Button { Haptics.impact(.light); onOpenAddSource(.link) } label: {
                    Label("Add Stream (.m3u8/.mp4)", systemImage: "link.badge.plus").frame(maxWidth: .infinity)
                }.buttonStyle(CVGlassButtonStyle(compact: true))

                Button { Haptics.impact(.light); onOpenAddSource(.file) } label: {
                    Label("Local File", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
                }.buttonStyle(CVGlassButtonStyle(compact: true))
            }

            if item.trailerURL != nil {
                Button {
                    Haptics.selection()
                    onPlayTrailer()
                } label: {
                    Label("Watch Official Trailer (Preview Only)", systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CVGlassButtonStyle(compact: true))
            }
        }
    }
}
