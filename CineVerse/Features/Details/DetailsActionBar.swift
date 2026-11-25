import SwiftUI

public struct DetailsActionBar: View {
    let primaryCTATitle: String
    let hasPlayableSource: Bool
    let hasTrailer: Bool
    let trackingStatus: WatchTrackingStatus?
    let inWatchlist: Bool
    let isFavorite: Bool
    let isAllWatched: Bool
    let shareURL: URL?
    let shareTitle: String

    let onPrimaryWatch: () -> Void
    let onWatchTrailer: () -> Void
    let onAddToList: () -> Void
    let onMarkWatched: () -> Void
    let onToggleFavorite: () -> Void

    public init(
        primaryCTATitle: String,
        hasPlayableSource: Bool,
        hasTrailer: Bool = false,
        trackingStatus: WatchTrackingStatus?,
        inWatchlist: Bool,
        isFavorite: Bool,
        isAllWatched: Bool,
        shareURL: URL?,
        shareTitle: String,
        onPrimaryWatch: @escaping () -> Void,
        onWatchTrailer: @escaping () -> Void = {},
        onAddToList: @escaping () -> Void,
        onMarkWatched: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.primaryCTATitle = primaryCTATitle
        self.hasPlayableSource = hasPlayableSource
        self.hasTrailer = hasTrailer
        self.trackingStatus = trackingStatus
        self.inWatchlist = inWatchlist
        self.isFavorite = isFavorite
        self.isAllWatched = isAllWatched
        self.shareURL = shareURL
        self.shareTitle = shareTitle
        self.onPrimaryWatch = onPrimaryWatch
        self.onWatchTrailer = onWatchTrailer
        self.onAddToList = onAddToList
        self.onMarkWatched = onMarkWatched
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        VStack(spacing: CVSpacing.sm) {
            HStack(spacing: CVSpacing.xs) {
                Button {
                    Haptics.impact(.medium)
                    onPrimaryWatch()
                } label: {
                    HStack(spacing: CVSpacing.xs) {
                        Image(systemName: hasPlayableSource ? "play.fill" : "play.tv")
                            .font(.subheadline.weight(.bold))
                        Text(hasPlayableSource ? primaryCTATitle : "Select Video Source")
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CVPrimaryButtonStyle())

                if hasTrailer {
                    Button {
                        Haptics.selection()
                        onWatchTrailer()
                    } label: {
                        Label("Trailer", systemImage: "film")
                    }
                    .buttonStyle(CVGlassButtonStyle())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CVSpacing.xs) {
                    Button {
                        Haptics.selection()
                        onAddToList()
                    } label: {
                        Label(listButtonLabel, systemImage: listButtonSymbol)
                    }
                    .buttonStyle(CVGlassButtonStyle(
                        compact: true,
                        tint: trackingStatus != nil ? Color(hex: trackingStatus?.accentHex ?? "#6E5BFF").opacity(0.25) : nil
                    ))

                    Button {
                        Haptics.notify(.success)
                        onMarkWatched()
                    } label: {
                        Label(
                            isAllWatched ? "Watched" : "Mark as Watched",
                            systemImage: isAllWatched ? "checkmark.seal.fill" : "checkmark.circle"
                        )
                    }
                    .buttonStyle(CVGlassButtonStyle(
                        compact: true,
                        tint: isAllWatched ? CVColor.success.opacity(0.22) : nil
                    ))

                    Button {
                        onToggleFavorite()
                    } label: {
                        Label(
                            "Favorite",
                            systemImage: isFavorite ? "heart.fill" : "heart"
                        )
                        .foregroundStyle(isFavorite ? Color.pink : Color.primary)
                    }
                    .buttonStyle(CVGlassButtonStyle(
                        compact: true,
                        tint: isFavorite ? Color.pink.opacity(0.22) : nil
                    ))
                    .sensoryFeedback(.impact(weight: .medium), trigger: isFavorite)

                    if let shareURL {
                        ShareLink(item: shareURL, subject: Text(shareTitle)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(CVGlassButtonStyle(compact: true))
                    } else {
                        ShareLink(item: shareTitle) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(CVGlassButtonStyle(compact: true))
                    }
                }
            }
        }
        .padding(.horizontal, CVSpacing.md)
    }

    private var listButtonLabel: String {
        if let trackingStatus {
            return trackingStatus.rawValue
        }
        return inWatchlist ? "In Watchlist" : "Add to List"
    }

    private var listButtonSymbol: String {
        if let trackingStatus {
            return trackingStatus.symbolName
        }
        return inWatchlist ? "bookmark.fill" : "plus"
    }
}
