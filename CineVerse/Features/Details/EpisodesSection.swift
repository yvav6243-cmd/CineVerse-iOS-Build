import SwiftUI

public struct EpisodesSection: View {
    let item: MediaItem
    let selectedSeasonNumber: Int
    let isLoadingSeason: Bool
    let seasonLoadError: String?
    let progressForEpisode: (MediaEpisode) -> PlaybackProgressRecord?
    let onSelectSeason: (Int) -> Void
    let onRetrySeason: () -> Void
    let onToggleWatched: (MediaEpisode) -> Void
    let onPlayEpisode: (MediaEpisode) -> Void

    @State private var showAllEpisodes: Bool = false

    private let initialDisplayLimit = 24

    public init(
        item: MediaItem,
        selectedSeasonNumber: Int,
        isLoadingSeason: Bool,
        seasonLoadError: String?,
        progressForEpisode: @escaping (MediaEpisode) -> PlaybackProgressRecord?,
        onSelectSeason: @escaping (Int) -> Void,
        onRetrySeason: @escaping () -> Void,
        onToggleWatched: @escaping (MediaEpisode) -> Void,
        onPlayEpisode: @escaping (MediaEpisode) -> Void
    ) {
        self.item = item
        self.selectedSeasonNumber = selectedSeasonNumber
        self.isLoadingSeason = isLoadingSeason
        self.seasonLoadError = seasonLoadError
        self.progressForEpisode = progressForEpisode
        self.onSelectSeason = onSelectSeason
        self.onRetrySeason = onRetrySeason
        self.onToggleWatched = onToggleWatched
        self.onPlayEpisode = onPlayEpisode
    }

    private var selectedSeason: MediaSeason? {
        item.seasons.first(where: { $0.seasonNumber == selectedSeasonNumber }) ?? item.seasons.first
    }

    private var episodes: [MediaEpisode] {
        (selectedSeason?.episodes ?? []).sorted { $0.episodeNumber < $1.episodeNumber }
    }

    private var visibleEpisodes: [MediaEpisode] {
        if showAllEpisodes || episodes.count <= initialDisplayLimit {
            return episodes
        }
        return Array(episodes.prefix(initialDisplayLimit))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            SectionHeader(
                title: "Episodes",
                subtitle: sectionSubtitle,
                symbolName: "list.bullet.rectangle.portrait",
                actionTitle: nil
            )

            if item.seasons.count > 1 {
                seasonPickerBar
            }

            if isLoadingSeason {
                loadingSeasonCard
            } else if let seasonLoadError {
                ErrorStateView(
                    title: "Could Not Load Episodes",
                    message: seasonLoadError,
                    retryAction: onRetrySeason
                )
            } else if episodes.isEmpty {
                CompactHintCard(
                    symbolName: "tv",
                    title: "No Episode List Available",
                    subtitle: "Episode details have not been published yet for this season."
                )
            } else {
                LazyVStack(spacing: CVSpacing.sm) {
                    ForEach(visibleEpisodes) { episode in
                        episodeCard(episode)
                    }

                    if !showAllEpisodes && episodes.count > initialDisplayLimit {
                        Button {
                            withAnimation(CVMotion.gentle) {
                                showAllEpisodes = true
                            }
                        } label: {
                            Text("Show All \(episodes.count) Episodes")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CVGlassButtonStyle(compact: true))
                        .padding(.horizontal, CVSpacing.md)
                    }
                }
            }
        }
        .onChange(of: selectedSeasonNumber) { _, _ in
            showAllEpisodes = false
        }
    }

    private var sectionSubtitle: String {
        if let season = selectedSeason {
            let count = max(season.episodeCount, season.episodes.count)
            return item.seasons.count > 1
                ? "\(season.title) • \(count) Episodes"
                : "\(count) Episodes"
        }
        return "\(max(item.totalEpisodes, 1)) Episodes"
    }

    private var seasonPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CVSpacing.xs) {
                ForEach(item.seasons.sorted { $0.seasonNumber < $1.seasonNumber }) { season in
                    FilterChip(
                        title: season.title,
                        isSelected: season.seasonNumber == selectedSeasonNumber
                    ) {
                        onSelectSeason(season.seasonNumber)
                    }
                }
            }
            .padding(.horizontal, CVSpacing.md)
        }
    }

    private var loadingSeasonCard: some View {
        HStack(spacing: CVSpacing.sm) {
            ProgressView()
            Text("Loading season episodes...")
                .font(CVFont.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(CVSpacing.md)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
    }

    private func episodeCard(_ episode: MediaEpisode) -> some View {
        let progress = progressForEpisode(episode)
        let isWatched = progress?.isWatched ?? false
        let fraction = progress?.fraction ?? 0

        return VStack(alignment: .leading, spacing: CVSpacing.xs) {
            HStack(alignment: .top, spacing: CVSpacing.sm) {
                ZStack(alignment: .bottom) {
                    CachedAsyncImage(
                        url: episode.stillImageURL ?? item.backdropURL ?? item.posterURL,
                        targetSize: CGSize(width: 240, height: 135),
                        fallbackSymbol: "tv"
                    )
                    .frame(width: 112, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: CVRadius.chip, style: .continuous))

                    if fraction > 0.01 && !isWatched {
                        CVProgressBar(fraction: fraction, height: 3.5)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                }
                .frame(width: 112, height: 64)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(episode.formattedCode)
                            .font(CVFont.micro)
                            .foregroundStyle(CVColor.iris)

                        if episode.durationMinutes > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text("\(episode.durationMinutes)m")
                        }

                        if let airDate = episode.airDate {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(CineVerseDateFormatters.mediumDisplay.string(from: airDate))
                        }
                    }
                    .font(CVFont.micro)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Text(episode.title)
                        .font(CVFont.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let progress, !isWatched, progress.positionSeconds > 5 {
                        Text("Resume at \(progress.positionSeconds.formattedPlaybackTime)")
                            .font(CVFont.micro)
                            .foregroundStyle(CVColor.iris)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Button {
                        onToggleWatched(episode)
                    } label: {
                        Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isWatched ? CVColor.success : Color.secondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isWatched)
                    .accessibilityLabel(isWatched ? "Mark episode unwatched" : "Mark episode watched")

                    Button {
                        Haptics.impact(.light)
                        onPlayEpisode(episode)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(CVColor.iris)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play \(episode.formattedCode)")
                }
            }

            if !episode.synopsis.isEmpty && episode.synopsis != "No episode description available." {
                ExpandableText(text: episode.synopsis, lineLimit: 2)
            }
        }
        .padding(CVSpacing.sm)
        .cvGlass(RoundedRectangle(cornerRadius: CVRadius.card, style: .continuous))
        .padding(.horizontal, CVSpacing.md)
    }
}
