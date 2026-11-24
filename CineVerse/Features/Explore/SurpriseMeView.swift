import SwiftUI

public struct SurpriseMeView: View {
    public enum SourceMode: String, CaseIterable, Identifiable {
        case catalog = "From Catalog"
        case watchlist = "From My Watchlist"

        public var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

    private let container: AppContainer

    @State private var sourceMode: SourceMode = .catalog
    @State private var selectedCategory: MediaProjectType? = nil
    @State private var pickedItem: MediaItem? = nil
    @State private var isSpinning: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isMissingTMDBKey: Bool = false
    @State private var isInWatchlist: Bool = false
    @State private var revealToken: Int = 0

    public init(container: AppContainer) {
        self.container = container
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CVSpacing.lg) {
                    controlsSection
                    resultSection
                }
                .padding(.vertical, CVSpacing.md)
            }
            .background(Color(.systemBackground))
            .navigationTitle(LocalizedStringKey("Surprise Me"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                if pickedItem == nil {
                    await spin()
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: CVSpacing.sm) {
            Picker("Source", selection: $sourceMode) {
                ForEach(SourceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, CVSpacing.md)
            .onChange(of: sourceMode) { _, _ in
                Task { await spin() }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    FilterChip(
                        title: "All Categories",
                        symbolName: "square.grid.2x2",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                        Task { await spin() }
                    }

                    ForEach(MediaProjectType.allCases) { category in
                        FilterChip(
                            title: category.pluralTitle,
                            symbolName: category.symbolName,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            Task { await spin() }
                        }
                    }
                }
                .padding(.horizontal, CVSpacing.md)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if isSpinning {
            VStack(spacing: CVSpacing.md) {
                RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 220, height: 330)
                    .cvShimmer(true)

                ProgressView("Picking something great...")
                    .font(CVFont.callout)
                    .tint(CVColor.iris)
            }
            .padding(.top, CVSpacing.lg)
        } else if isMissingTMDBKey {
            ErrorStateView(
                title: "TMDB API Key Required",
                message: errorMessage ?? NetworkError.missingAPIKey(.tmdb).localizedDescription,
                symbolName: "key.fill",
                actionTitle: "Open API Keys"
            ) {
                dismiss()
                container.coordinator.navigate(to: .apiKeys)
            }
            .padding(.top, CVSpacing.lg)
        } else if let errorMessage {
            ErrorStateView(message: errorMessage) {
                Task { await spin() }
            }
            .padding(.top, CVSpacing.lg)
        } else if let pickedItem {
            pickedCard(for: pickedItem)
                .id("\(pickedItem.id)-\(revealToken)")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
        } else {
            EmptyStateView(
                title: sourceMode == .watchlist ? "No Watchlist Match" : "No Match Found",
                message: sourceMode == .watchlist
                    ? "Add titles to your watchlist or switch to From Catalog to spin from all providers."
                    : "Try selecting another category and spinning again.",
                symbolName: "dice",
                actionTitle: "Spin Again"
            ) {
                Task { await spin() }
            }
            .padding(.top, CVSpacing.lg)
        }
    }

    private func pickedCard(for item: MediaItem) -> some View {
        VStack(spacing: CVSpacing.md) {
            CachedAsyncImage(
                url: item.posterURL ?? item.backdropURL,
                targetSize: CGSize(width: 440, height: 660),
                contentMode: .fill,
                fallbackSymbol: item.projectType.symbolName
            )
            .frame(width: 220, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)

            VStack(spacing: CVSpacing.xs) {
                HStack(spacing: CVSpacing.xs) {
                    TypeBadge(projectType: item.projectType)
                    RatingBadge(score: item.displayRating, compact: false)
                    if item.releaseYear > 0 {
                        Text(String(item.releaseYear))
                            .font(CVFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    }
                }

                Text(item.localizedTitle)
                    .font(CVFont.pageTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if !item.originalTitle.isEmpty,
                   item.originalTitle.caseInsensitiveCompare(item.localizedTitle) != .orderedSame {
                    Text(item.originalTitle)
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !item.genres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CVSpacing.xs) {
                            ForEach(item.genres.prefix(4), id: \.self) { genre in
                                GenreChip(title: genre)
                            }
                        }
                        .padding(.horizontal, CVSpacing.md)
                    }
                }

                if !item.synopsis.isEmpty {
                    Text(item.synopsis)
                        .font(CVFont.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, CVSpacing.lg)
                        .padding(.top, 2)
                }
            }

            VStack(spacing: CVSpacing.sm) {
                HStack(spacing: CVSpacing.sm) {
                    Button {
                        Haptics.impact(.medium)
                        dismiss()
                        if let ref = item.reference {
                            container.coordinator.navigate(to: .details(ref))
                        }
                    } label: {
                        Label("Open Details", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CVPrimaryButtonStyle())

                    Button {
                        let added = container.libraryRepository.toggleWatchlist(for: item)
                        isInWatchlist = added
                        Haptics.notify(added ? .success : .warning)
                    } label: {
                        Label(
                            isInWatchlist ? "In Watchlist" : "Add to Watchlist",
                            systemImage: isInWatchlist ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .buttonStyle(CVGlassButtonStyle())
                }

                Button {
                    Task { await spin() }
                } label: {
                    Label("Spin Again", systemImage: "dice.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CVGlassButtonStyle())
            }
            .padding(.horizontal, CVSpacing.lg)
        }
    }

    private func spin() async {
        Haptics.impact(.light)
        isSpinning = true
        errorMessage = nil
        isMissingTMDBKey = false

        let previousID = pickedItem?.id

        switch sourceMode {
        case .catalog:
            var criteria = CatalogFilterCriteria()
            criteria.selectedCategory = selectedCategory
            do {
                let picked = try await container.catalogRepository.randomPick(
                    criteria: criteria,
                    language: container.settingsStore.contentLanguageCode
                )
                withAnimation(CVMotion.spring) {
                    pickedItem = picked
                    isInWatchlist = picked.flatMap { container.libraryRepository.entry(for: $0.id)?.inWatchlist } ?? false
                    revealToken += 1
                    isSpinning = false
                }
                if picked != nil {
                    Haptics.notify(.success)
                }
            } catch NetworkError.missingAPIKey(.tmdb) {
                isMissingTMDBKey = true
                errorMessage = NetworkError.missingAPIKey(.tmdb).localizedDescription
                pickedItem = nil
                isSpinning = false
            } catch {
                errorMessage = error.localizedDescription
                pickedItem = nil
                isSpinning = false
            }

        case .watchlist:
            let entries = container.libraryRepository.allEntries().filter { entry in
                guard entry.inWatchlist else { return false }
                if let selectedCategory {
                    return entry.projectType == selectedCategory
                }
                return true
            }

            let pool: [LibraryEntryRecord]
            if entries.count > 1, let previousID {
                pool = entries.filter { $0.mediaID != previousID }
            } else {
                pool = entries
            }

            let chosen = pool.randomElement()
            let mapped = chosen.map(mediaItem(from:))

            withAnimation(CVMotion.spring) {
                pickedItem = mapped
                isInWatchlist = chosen?.inWatchlist ?? false
                revealToken += 1
                isSpinning = false
            }
            if mapped != nil {
                Haptics.notify(.success)
            }
        }
    }

    private func mediaItem(from entry: LibraryEntryRecord) -> MediaItem {
        if let snap = entry.snapshot {
            return snap
        }
        return MediaItem(
            id: entry.mediaID,
            primarySource: MediaReference(id: entry.mediaID)?.provider ?? .openCinema,
            projectType: entry.projectType,
            localizedTitle: entry.title,
            originalTitle: entry.originalTitle,
            synopsis: entry.notes,
            releaseYear: entry.releaseYear,
            countryOfOrigin: "US",
            originalLanguage: "en",
            genres: entry.genres,
            durationMinutes: entry.episodeDurationMinutes,
            totalSeasons: entry.totalSeasons,
            totalEpisodes: entry.totalEpisodes,
            ratings: MultiSourceRatings(),
            posterURL: entry.posterURL,
            backdropURL: entry.backdropURL
        )
    }
}
