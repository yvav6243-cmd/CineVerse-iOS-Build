import Foundation

public struct ContentAvailabilitySummary: Equatable, Sendable {
    public let status: ContentAvailabilityStatus
    public let canWatchInApp: Bool
    public let playableSourceCount: Int
    public let officialSourceCount: Int
    public let audioLanguages: [String]
    public let highestQualityLabel: String?
    public let explanation: String

    public init(
        status: ContentAvailabilityStatus,
        canWatchInApp: Bool,
        playableSourceCount: Int,
        officialSourceCount: Int,
        audioLanguages: [String],
        highestQualityLabel: String?,
        explanation: String
    ) {
        self.status = status
        self.canWatchInApp = canWatchInApp
        self.playableSourceCount = playableSourceCount
        self.officialSourceCount = officialSourceCount
        self.audioLanguages = audioLanguages
        self.highestQualityLabel = highestQualityLabel
        self.explanation = explanation
    }
}

public enum ContentAvailabilityResolver {
    public static func resolve(
        item: MediaItem,
        sources: [VideoSourceDescriptor],
        now: Date = Date()
    ) -> ContentAvailabilitySummary {
        let playable = sources.filter {
            $0.isAvailable && $0.format.isDirectlyPlayable && $0.healthStatus.isHealthyOrUnchecked
        }
        let official = sources.filter { $0.format == .externalOfficialService }

        var langSet: Set<String> = []
        var audioLanguages: [String] = []
        for src in playable {
            for track in src.availableAudioTracks {
                let display = track.displayName.nilIfEmpty
                    ?? LanguageCatalog.displayName(forLanguageCode: track.languageCode)
                if langSet.insert(display.lowercased()).inserted {
                    audioLanguages.append(display)
                }
            }
        }
        if audioLanguages.isEmpty && !playable.isEmpty {
            let fallbackLang = LanguageCatalog.displayName(forLanguageCode: item.originalLanguage.nilIfEmpty ?? "en")
            audioLanguages = [fallbackLang]
        }

        let highestQuality: String? = {
            guard !playable.isEmpty else { return nil }
            let bestConcrete = playable
                .flatMap(\.availableQualities)
                .filter { $0.tier != .auto }
                .max { $0.tier.resolutionPriorityRank < $1.tier.resolutionPriorityRank }
            if let bestConcrete {
                return bestConcrete.tier.shortBadge
            }
            return playable.first?.highestQualityLabel
        }()

        let status: ContentAvailabilityStatus
        let explanation: String

        if !playable.isEmpty {
            if playable.contains(where: { $0.providerID == "local_file" || $0.providerID == "direct_link" }) {
                status = .userProvided
                explanation = "Playable in CineVerse Player using your attached file or verified stream URL."
            } else if playable.contains(where: { $0.providerID == "internet_archive" || $0.providerID == "wikimedia_cinema" }) {
                status = .publicDomain
                explanation = "Legal public domain or Creative Commons full-length stream ready for built-in playback."
            } else {
                status = .availableToWatch
                explanation = "Verified full-length video stream ready for built-in CineVerse playback."
            }
        } else if !official.isEmpty {
            status = .officialStreaming
            let names = official.prefix(3).map(\.providerName).joined(separator: ", ")
            explanation = "No open direct stream is available. Available on official platforms (\(names)), or attach your own stream."
        } else if isUpcoming(item, now: now) {
            if let relDate = item.releaseDate, relDate.timeIntervalSince(now) <= 180 * 86_400 {
                status = .comingSoon
                explanation = "Premiere scheduled soon. Enable release alerts to be notified when playback becomes available."
            } else {
                status = .notYetReleased
                explanation = "This project has not been released yet. Posters, synopsis, and release updates are tracked here."
            }
        } else if item.trailerURL != nil {
            status = .trailerOnly
            explanation = "Only an official trailer preview is currently available. Trailers are never substituted for full films."
        } else {
            status = .informationOnly
            explanation = "Catalog metadata entry. No verified full-length stream is attached yet—add your own URL/file or enable alerts."
        }

        return ContentAvailabilitySummary(
            status: status,
            canWatchInApp: status.canWatchInApp && !playable.isEmpty,
            playableSourceCount: playable.count,
            officialSourceCount: official.count,
            audioLanguages: audioLanguages,
            highestQualityLabel: highestQuality,
            explanation: explanation
        )
    }

    public static func quickStatus(
        for item: MediaItem,
        userPlayableMediaIDs: Set<String> = [],
        now: Date = Date()
    ) -> ContentAvailabilityStatus {
        if userPlayableMediaIDs.contains(item.id) {
            return .userProvided
        }
        let openStreams = OpenCinemaLibrary.streams(forItemID: item.id)
        let hasDirectEpisodes = item.seasons.contains { season in
            season.episodes.contains { $0.directStreamURL != nil }
        }
        if item.primarySource == .internetArchive || item.externalIDs[.internetArchive] != nil {
            return .publicDomain
        }
        if let rawOpen = item.externalIDs[.openCinema], rawOpen.hasPrefix("wmfile:") {
            return .publicDomain
        }
        if !openStreams.isEmpty || hasDirectEpisodes {
            return .availableToWatch
        }
        if !item.officialPlatformLinks.isEmpty {
            return .officialStreaming
        }
        if isUpcoming(item, now: now) {
            if let relDate = item.releaseDate, relDate.timeIntervalSince(now) <= 180 * 86_400 {
                return .comingSoon
            }
            return .notYetReleased
        }
        if item.trailerURL != nil {
            return .trailerOnly
        }
        return .informationOnly
    }

    private static func isUpcoming(_ item: MediaItem, now: Date) -> Bool {
        if item.releaseStatus == .upcoming { return true }
        if let relDate = item.releaseDate, relDate > now { return true }
        let currentYear = Calendar.current.component(.year, from: now)
        return item.releaseYear > currentYear
    }
}
