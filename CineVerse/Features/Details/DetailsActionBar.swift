import SwiftUI

public struct DetailsActionBar: View {
    let primaryCTATitle: String
    let hasPlayableSource: Bool
    let availabilityStatus: ContentAvailabilityStatus
    let hasTrailer: Bool
    let trackingStatus: WatchTrackingStatus?
    let inWatchlist: Bool
    let isFavorite: Bool
    let isAllWatched: Bool
    let alertsEnabled: Bool
    let shareURL: URL?
    let shareTitle: String

    let onPrimaryWatch: () -> Void
    let onWatchTrailer: () -> Void
    let onOpenOfficialPlatforms: () -> Void
    let onOpenAddSource: () -> Void
    let onToggleAlerts: () -> Void
    let onAddToList: () -> Void
    let onMarkWatched: () -> Void
    let onToggleFavorite: () -> Void

    public init(
        primaryCTATitle: String,
        hasPlayableSource: Bool,
        availabilityStatus: ContentAvailabilityStatus = .informationOnly,
        hasTrailer: Bool = false,
        trackingStatus: WatchTrackingStatus?,
        inWatchlist: Bool,
        isFavorite: Bool,
        isAllWatched: Bool,
        alertsEnabled: Bool = false,
        shareURL: URL?,
        shareTitle: String,
        onPrimaryWatch: @escaping () -> Void,
        onWatchTrailer: @escaping () -> Void = {},
        onOpenOfficialPlatforms: @escaping () -> Void = {},
        onOpenAddSource: @escaping () -> Void = {},
        onToggleAlerts: @escaping () -> Void = {},
        onAddToList: @escaping () -> Void,
        onMarkWatched: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) {
        self.primaryCTATitle = primaryCTATitle
        self.hasPlayableSource = hasPlayableSource
        self.availabilityStatus = availabilityStatus
        self.hasTrailer = hasTrailer
        self.trackingStatus = trackingStatus
        self.inWatchlist = inWatchlist
        self.isFavorite = isFavorite
        self.isAllWatched = isAllWatched
        self.alertsEnabled = alertsEnabled
        self.shareURL = shareURL
        self.shareTitle = shareTitle
        self.onPrimaryWatch = onPrimaryWatch
        self.onWatchTrailer = onWatchTrailer
        self.onOpenOfficialPlatforms = onOpenOfficialPlatforms
        self.onOpenAddSource = onOpenAddSource
        self.onToggleAlerts = onToggleAlerts
        self.onAddToList = onAddToList
        self.onMarkWatched = onMarkWatched
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        VStack(spacing: CVSpacing.sm) {
            HStack(spacing: CVSpacing.xs) {
                primaryActionButton

                if hasTrailer && !(availabilityStatus == .trailerOnly && !hasPlayableSource) {
                    Button {
                        Haptics.selection()
                        onWatchTrailer()
                    } label: {
                        Label("Trailer", systemImage: "film")
                    }
                    .buttonStyle(CVGlassButtonStyle())
                } else if !hasPlayableSource {
                    Button {
                        Haptics.selection()
                        onOpenAddSource()
                    } label: {
                        Label("Add Source", systemImage: "plus.circle")
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
                        Haptics.selection()
                        onToggleAlerts()
                    } label: {
                        Label(
                            alertsEnabled ? "Alert On" : "Notify Me",
                            systemImage: alertsEnabled ? "bell.fill" : "bell"
                        )
                        .foregroundStyle(alertsEnabled ? CVColor.amber : Color.primary)
                    }
                    .buttonStyle(CVGlassButtonStyle(
                        compact: true,
                        tint: alertsEnabled ? CVColor.amber.opacity(0.22) : nil
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

    @ViewBuilder
    private var primaryActionButton: some View {
        if hasPlayableSource && availabilityStatus.canWatchInApp {
            Button {
                Haptics.impact(.medium)
                onPrimaryWatch()
            } label: {
                HStack(spacing: CVSpacing.xs) {
                    Image(systemName: "play.fill").font(.subheadline.weight(.bold))
                    Text(primaryCTATitle).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVPrimaryButtonStyle())
        } else if availabilityStatus == .officialStreaming {
            Button {
                Haptics.selection()
                onOpenOfficialPlatforms()
            } label: {
                HStack(spacing: CVSpacing.xs) {
                    Image(systemName: "arrow.up.right.square").font(.subheadline.weight(.bold))
                    Text("Official Platforms").lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVGlassButtonStyle())
        } else if availabilityStatus == .comingSoon || availabilityStatus == .notYetReleased {
            Button {
                Haptics.selection()
                onToggleAlerts()
            } label: {
                HStack(spacing: CVSpacing.xs) {
                    Image(systemName: alertsEnabled ? "bell.fill" : "bell.badge").font(.subheadline.weight(.bold))
                    Text(alertsEnabled ? "Release Alert Enabled" : "Notify When Available").lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVPrimaryButtonStyle())
        } else if availabilityStatus == .trailerOnly && hasTrailer {
            Button {
                Haptics.selection()
                onWatchTrailer()
            } label: {
                HStack(spacing: CVSpacing.xs) {
                    Image(systemName: "film").font(.subheadline.weight(.bold))
                    Text("Watch Trailer (Preview)").lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVGlassButtonStyle())
        } else {
            Button {
                Haptics.impact(.light)
                onOpenAddSource()
            } label: {
                HStack(spacing: CVSpacing.xs) {
                    Image(systemName: "plus.circle.fill").font(.subheadline.weight(.bold))
                    Text("Add Video Source").lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CVGlassButtonStyle())
        }
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
