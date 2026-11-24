import SwiftUI

public enum AddSourceTab: String, CaseIterable, Identifiable, Sendable {
    case link = "HTTPS Link (.m3u8 / .mp4)"
    case file = "Local Video File"
    public var id: String { rawValue }
}

public struct PlaybackSetupPanel: View {
    let item: MediaItem
    @Bindable var viewModel: PlaybackSetupViewModel
    let startPositionSeconds: TimeInterval
    let onSelectEpisode: (MediaEpisode) -> Void
    let onStartWatching: (PreWatchPlaybackSelection) -> Void
    let onOpenAddSource: (AddSourceTab) -> Void
    let onImportSubtitle: () -> Void
    let onOpenOfficialURL: (URL) -> Void
    let onPlayTrailer: () -> Void

    public init(
        item: MediaItem,
        viewModel: PlaybackSetupViewModel,
        startPositionSeconds: TimeInterval,
        onSelectEpisode: @escaping (MediaEpisode) -> Void,
        onStartWatching: @escaping (PreWatchPlaybackSelection) -> Void,
        onOpenAddSource: @escaping (AddSourceTab) -> Void,
        onImportSubtitle: @escaping () -> Void,
        onOpenOfficialURL: @escaping (URL) -> Void,
        onPlayTrailer: @escaping () -> Void
    ) {
        self.item = item
        self.viewModel = viewModel
        self.startPositionSeconds = startPositionSeconds
        self.onSelectEpisode = onSelectEpisode
        self.onStartWatching = onStartWatching
        self.onOpenAddSource = onOpenAddSource
        self.onImportSubtitle = onImportSubtitle
        self.onOpenOfficialURL = onOpenOfficialURL
        self.onPlayTrailer = onPlayTrailer
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
                    Text("Checking available video streams and tracks...")
                        .font(CVFont.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, CVSpacing.xs)
            } else if viewModel.hasPlayableSource, let source = viewModel.selectedSource {
                menusSection(source: source)

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
        HStack(spacing: CVSpacing.xs) {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CVColor.iris)
            Text("Playback Setup").font(CVFont.sectionTitle)
            Spacer()
            if viewModel.isInspecting || viewModel.isResolving {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var episodeSelectorRow: some View {
        let allEpisodes = item.seasons
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
        } else if let current = viewModel.selectedEpisode {
            Label("Target Episode: \(current.formattedCode) · \(current.title)", systemImage: "tv")
                .font(CVFont.caption.weight(.semibold))
                .foregroundStyle(CVColor.iris)
                .lineLimit(1)
        }
    }

    private func menusSection(source: VideoSourceDescriptor) -> some View {
        VStack(spacing: 0) {
            sourceMenuRow(selected: source)
            Divider().padding(.leading, 34)
            qualityMenuRow
            Divider().padding(.leading, 34)
            voiceoverMenuRow
            Divider().padding(.leading, 34)
            subtitlesMenuRow
        }
        .background(Color(.tertiarySystemFill).opacity(0.45), in: RoundedRectangle(cornerRadius: CVRadius.poster, style: .continuous))
    }

    private func sourceMenuRow(selected: VideoSourceDescriptor) -> some View {
        Menu {
            ForEach(viewModel.playableSources) { src in
                Button {
                    Haptics.selection()
                    Task { await viewModel.selectSource(src) }
                } label: {
                    menuOptionLabel("\(src.providerName) (\(src.format.badgeText))", selected: src.id == selected.id)
                }
            }

            let userSources = viewModel.playableSources.filter { viewModel.isUserSource($0) }
            if !userSources.isEmpty {
                Divider()
                Menu("Remove Attached Source") {
                    ForEach(userSources) { src in
                        Button(role: .destructive) {
                            Haptics.impact(.medium)
                            Task { await viewModel.deleteSource(src) }
                        } label: {
                            Label("Delete \(src.providerName)", systemImage: "trash")
                        }
                    }
                }
            }

            Divider()
            Button { onOpenAddSource(.link) } label: {
                Label("Add Video Link / File", systemImage: "plus.circle")
            }
        } label: {
            setupRowContent(
                icon: "play.tv",
                title: "Source",
                value: selected.providerName,
                badgeText: selected.format.badgeText,
                badgeTint: CVColor.iris
            )
        }
        .buttonStyle(.plain)
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
                value: viewModel.selectedQuality?.detailedLabel ?? "Auto (Adaptive)"
            )
        }
        .buttonStyle(.plain)
    }

    private var voiceoverMenuRow: some View {
        Menu {
            if viewModel.availableAudioTracks.isEmpty {
                Text("Default Stream Audio")
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
                value: track.map { "\($0.displayName) · \($0.voiceoverStudio)" } ?? "Default Audio",
                badgeText: (track?.isOriginal == true) ? "Original" : nil,
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
                Text(badgeText)
                    .font(CVFont.micro)
                    .foregroundStyle(badgeTint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badgeTint.opacity(0.16), in: Capsule(style: .continuous))
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
                Text(startPositionSeconds > 5 ? "Start Watching · Resume \(startPositionSeconds.formattedPlaybackTime)" : "Start Watching")
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CVPrimaryButtonStyle())
        .disabled(viewModel.isInspecting)
    }

    private var noPlayableSourceFallback: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            HStack(spacing: CVSpacing.sm) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CVColor.iris)
                    .frame(width: 38, height: 38)
                    .background(CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Open Stream for This Title").font(CVFont.cardTitle)
                    Text(fallbackDescription).font(CVFont.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if item.trailerURL != nil {
                Button {
                    Haptics.impact(.medium)
                    onPlayTrailer()
                } label: {
                    Label("Play Trailer in CineVerse Player", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CVPrimaryButtonStyle())
            }

            HStack(spacing: CVSpacing.xs) {
                Button { Haptics.impact(.light); onOpenAddSource(.file) } label: {
                    Label("Local File", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
                }.buttonStyle(CVGlassButtonStyle(compact: true))

                Button { Haptics.impact(.light); onOpenAddSource(.link) } label: {
                    Label("Custom Stream", systemImage: "plus.circle").frame(maxWidth: .infinity)
                }.buttonStyle(CVGlassButtonStyle(compact: true))
            }

            if !viewModel.officialSources.isEmpty {
                Divider().padding(.vertical, 2)
                Text("Official Streaming Platforms").font(CVFont.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CVSpacing.xs) {
                        ForEach(viewModel.officialSources) { official in
                            if let url = official.officialServiceURL {
                                Button { Haptics.selection(); onOpenOfficialURL(url) } label: {
                                    Label("Open in \(official.providerName)", systemImage: "play.tv")
                                }.buttonStyle(CVGlassButtonStyle(compact: true))
                            }
                        }
                    }
                }
            }
        }
    }

    private var fallbackDescription: String {
        "Full episodes and films are only available from licensed services. Play the official trailer in the CineVerse player, or attach your own stream or file."
    }
}
