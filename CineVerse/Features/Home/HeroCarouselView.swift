import SwiftUI

public struct HeroCarouselView: View {
    let items: [MediaItem]
    @Binding var activeItemID: String?
    let isInWatchlist: (MediaItem) -> Bool
    let onOpen: (MediaItem) -> Void
    let onToggleWatchlist: (MediaItem) -> Void

    private let cardHeight: CGFloat = 380

    public init(
        items: [MediaItem],
        activeItemID: Binding<String?>,
        isInWatchlist: @escaping (MediaItem) -> Bool,
        onOpen: @escaping (MediaItem) -> Void,
        onToggleWatchlist: @escaping (MediaItem) -> Void
    ) {
        self.items = items
        self._activeItemID = activeItemID
        self.isInWatchlist = isInWatchlist
        self.onOpen = onOpen
        self.onToggleWatchlist = onToggleWatchlist
    }

    public var body: some View {
        VStack(spacing: CVSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        heroSlide(for: item)
                            .id(item.id)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $activeItemID)
            .frame(height: cardHeight)

            if items.count > 1 {
                pageIndicator
            }
        }
        .task(id: items.map(\.id)) {
            guard items.count > 1 else {
                if activeItemID == nil {
                    activeItemID = items.first?.id
                }
                return
            }

            if activeItemID == nil || !items.contains(where: { $0.id == activeItemID }) {
                activeItemID = items.first?.id
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled, items.count > 1 else { break }

                let currentIndex = items.firstIndex(where: { $0.id == activeItemID }) ?? 0
                let nextIndex = (currentIndex + 1) % items.count
                withAnimation(CVMotion.spring) {
                    activeItemID = items[nextIndex].id
                }
            }
        }
    }

    private func heroSlide(for item: MediaItem) -> some View {
        let saved = isInWatchlist(item)
        let imageURL = item.backdropURL ?? item.posterURL

        return ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: imageURL,
                targetSize: CGSize(width: 960, height: 600),
                contentMode: .fill,
                fallbackSymbol: item.projectType.symbolName
            )
            .frame(maxWidth: .infinity, maxHeight: cardHeight)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.08), location: 0.0),
                    .init(color: Color.black.opacity(0.25), location: 0.42),
                    .init(color: Color.black.opacity(0.86), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: CVSpacing.xs) {
                HStack(spacing: CVSpacing.xs) {
                    TypeBadge(projectType: item.projectType)
                    RatingBadge(score: item.displayRating, compact: false)
                    Spacer()
                }
                .environment(\.colorScheme, .dark)

                Text(item.localizedTitle)
                    .font(CVFont.pageTitle)
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metadataRow(for: item)

                HStack(spacing: CVSpacing.sm) {
                    Button {
                        Haptics.impact(.light)
                        onOpen(item)
                    } label: {
                        Label("Open", systemImage: "play.fill")
                    }
                    .buttonStyle(CVPrimaryButtonStyle(compact: true))

                    Button {
                        onToggleWatchlist(item)
                    } label: {
                        Label(
                            saved ? "In Watchlist" : "Add to Watchlist",
                            systemImage: saved ? "bookmark.fill" : "bookmark"
                        )
                        .font(CVFont.caption.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, CVSpacing.sm)
                        .padding(.vertical, CVSpacing.xs + 1)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .environment(\.colorScheme, .dark)
                }
                .padding(.top, CVSpacing.xxs)
            }
            .padding(CVSpacing.lg)
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 8)
        .padding(.horizontal, CVSpacing.md)
        .contentShape(RoundedRectangle(cornerRadius: CVRadius.panel, style: .continuous))
        .onTapGesture {
            Haptics.selection()
            onOpen(item)
        }
    }

    @ViewBuilder
    private func metadataRow(for item: MediaItem) -> some View {
        let genreText = item.genres.prefix(3).joined(separator: " · ")
        let yearText = item.releaseYear > 0 ? String(item.releaseYear) : ""
        let parts = [yearText, genreText].filter { !$0.isEmpty }

        if !parts.isEmpty {
            Text(parts.joined(separator: "  •  "))
                .font(CVFont.caption)
                .foregroundStyle(Color.white.opacity(0.84))
                .lineLimit(1)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let isActive = (activeItemID ?? items.first?.id) == item.id
                Button {
                    Haptics.selection()
                    withAnimation(CVMotion.spring) {
                        activeItemID = item.id
                    }
                } label: {
                    Capsule(style: .continuous)
                        .fill(isActive ? CVColor.iris : Color.secondary.opacity(0.32))
                        .frame(width: isActive ? 20 : 6, height: 6)
                        .animation(CVMotion.snappy, value: isActive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show featured item \(item.localizedTitle)")
            }
        }
        .padding(.vertical, 2)
    }
}
