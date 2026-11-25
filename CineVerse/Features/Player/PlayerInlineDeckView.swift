import SwiftUI

public struct PlayerInlineDeckView: View {
    let session: PlayerSession
    let scalingMode: VideoScalingMode
    let onSelectScalingMode: (VideoScalingMode) -> Void
    let onEnterFullscreen: () -> Void
    let onOpenSettings: () -> Void

    private let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    @State private var selectedSeasonNumber: Int = 1

    public init(
        session: PlayerSession,
        scalingMode: VideoScalingMode = .fit,
        onSelectScalingMode: @escaping (VideoScalingMode) -> Void = { _ in },
        onEnterFullscreen: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.session = session
        self.scalingMode = scalingMode
        self.onSelectScalingMode = onSelectScalingMode
        self.onEnterFullscreen = onEnterFullscreen
        self.onOpenSettings = onOpenSettings
        _selectedSeasonNumber = State(initialValue: session.selection.episode?.seasonNumber ?? 1)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CVSpacing.md) {
                headerAndTelemetryCard
                quickSpeedAndAudioSection
                if !session.alternativeSources.isEmpty {
                    verifiedSourcesSection
                }
                if !session.selection.mediaItem.seasons.isEmpty {
                    episodesSwitcherSection
                }
            }
            .padding(CVSpacing.md)
        }
        .background(CVColor.canvas)
    }

    private var headerAndTelemetryCard: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.selection.mediaItem.localizedTitle)
                        .font(CVFont.sectionTitle)
                        .foregroundStyle(.primary)
                    if let ep = session.selection.episode {
                        Text("Season \(ep.seasonNumber), Episode \(ep.episodeNumber) · \(ep.title)")
                            .font(CVFont.caption.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                    } else {
                        Text("\(session.selection.source.providerName) · Full-Length Stream")
                            .font(CVFont.caption.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                    }
                }
                Spacer()
                Button {
                    Haptics.impact(.medium)
                    onEnterFullscreen()
                } label: {
                    Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(CVPrimaryButtonStyle(compact: true))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 7, height: 7)
                    Text("\(session.engine.playbackState.rawValue) · \(session.engine.diagnostics.fullTechnicalSummary)")
                        .font(CVFont.micro.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let limitNote = session.sourceQualityLimitationNote {
                    Text(limitNote)
                        .font(CVFont.micro)
                        .foregroundStyle(CVColor.warning)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(CVSpacing.sm)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
    }

    private var statusDotColor: Color {
        switch session.engine.playbackState {
        case .playing, .ready: return CVColor.success
        case .loading, .buffering: return CVColor.warning
        case .paused: return .secondary
        case .failed: return CVColor.danger
        }
    }

    private var quickSpeedAndAudioSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack {
                Text("Voiceovers, Quality & Speed")
                    .font(CVFont.cardTitle)
                Spacer()
                Button("All Options", action: onOpenSettings)
                    .font(CVFont.caption.weight(.semibold))
                    .foregroundStyle(CVColor.iris)
            }

            if !session.engine.availableAudioTracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CVSpacing.xs) {
                        ForEach(session.engine.availableAudioTracks) { track in
                            let active = session.engine.selectedAudioTrack?.id == track.id
                            Button {
                                Haptics.selection()
                                session.selectAudio(track)
                            } label: {
                                Label(track.fullLabel, systemImage: track.isOriginal ? "sparkles" : "waveform")
                                    .font(CVFont.caption.weight(.semibold))
                                    .foregroundStyle(active ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        active ? AnyShapeStyle(CVColor.brandGradient) : AnyShapeStyle(.ultraThinMaterial),
                                        in: Capsule(style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(VideoScalingMode.allCases) { mode in
                        let active = scalingMode == mode
                        Button {
                            Haptics.selection()
                            onSelectScalingMode(mode)
                        } label: {
                            Label(mode.rawValue, systemImage: mode.symbolName)
                                .font(CVFont.micro.weight(.bold))
                                .foregroundStyle(active ? .white : .secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    active ? AnyShapeStyle(CVColor.iris) : AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule(style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(rates, id: \.self) { rate in
                        let active = session.engine.playbackRate == rate
                        Button {
                            Haptics.selection()
                            session.engine.setRate(rate)
                        } label: {
                            Text(rate == 1.0 ? "1x" : String(format: "%.2gx", rate))
                                .font(CVFont.micro.weight(.bold))
                                .foregroundStyle(active ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    active ? AnyShapeStyle(CVColor.iris) : AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule(style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var verifiedSourcesSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack {
                Text("Verified Full-Length Sources")
                    .font(CVFont.cardTitle)
                Spacer()
                if session.isSwitchingSource {
                    ProgressView().controlSize(.small)
                }
            }

            ForEach(session.alternativeSources) { src in
                let isSelected = src.id == session.selection.source.id
                Button {
                    Haptics.selection()
                    Task { await session.switchSource(to: src) }
                } label: {
                    HStack(spacing: CVSpacing.sm) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(src.providerName)
                                    .font(CVFont.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(src.format.badgeText)
                                    .font(CVFont.micro.weight(.bold))
                                    .foregroundStyle(CVColor.iris)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(CVColor.iris.opacity(0.14), in: Capsule())
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
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "play.circle")
                            .foregroundStyle(isSelected ? CVColor.iris : .secondary)
                            .font(.title3)
                    }
                    .padding(CVSpacing.sm)
                    .cvGlass(RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var episodesSwitcherSection: some View {
        let seasons = session.selection.mediaItem.seasons
        let currentSeason = seasons.first(where: { $0.seasonNumber == selectedSeasonNumber }) ?? seasons.first
        return VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack {
                Text("Episodes")
                    .font(CVFont.cardTitle)
                Spacer()
                if seasons.count > 1 {
                    Menu {
                        ForEach(seasons) { s in
                            Button(s.title) { selectedSeasonNumber = s.seasonNumber }
                        }
                    } label: {
                        Label(currentSeason?.title ?? "Season", systemImage: "chevron.up.chevron.down")
                            .font(CVFont.caption.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                    }
                }
            }

            if let episodes = currentSeason?.episodes {
                ForEach(episodes) { ep in
                    let isPlayingEp = ep.id == session.selection.episode?.id
                    Button {
                        Haptics.selection()
                        Task { await session.switchEpisode(to: ep) }
                    } label: {
                        HStack(spacing: CVSpacing.sm) {
                            Text("E\(ep.episodeNumber)")
                                .font(CVFont.caption.weight(.bold))
                                .foregroundStyle(isPlayingEp ? .white : CVColor.iris)
                                .frame(width: 38, height: 32)
                                .background(isPlayingEp ? CVColor.iris : CVColor.iris.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ep.title)
                                    .font(CVFont.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(ep.durationMinutes) min")
                                    .font(CVFont.micro)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isPlayingEp {
                                Image(systemName: "waveform")
                                    .foregroundStyle(CVColor.iris)
                            }
                        }
                        .padding(CVSpacing.xs)
                        .cvGlass(RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
