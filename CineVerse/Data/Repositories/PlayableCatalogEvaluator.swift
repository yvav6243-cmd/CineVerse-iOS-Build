import Foundation

public struct PlayableSourceCapabilities: Sendable, Hashable {
    public let isPlayable: Bool
    public let highestTier: VideoQualityTier
    public let audioLanguages: Set<String>
    public let voiceoverKinds: Set<AudioVoiceoverKind>

    public static let none = PlayableSourceCapabilities(
        isPlayable: false,
        highestTier: .p360,
        audioLanguages: [],
        voiceoverKinds: []
    )
}

public enum PlayableCatalogEvaluator {
    /// Evaluates whether `item` has a REAL verified full-length playback source (never counting trailers or catalog-only entries).
    public static func capabilities(
        for item: MediaItem,
        userPlayableMediaIDs: Set<String> = []
    ) -> PlayableSourceCapabilities {
        if userPlayableMediaIDs.contains(item.id) {
            return PlayableSourceCapabilities(
                isPlayable: true,
                highestTier: .p4K,
                audioLanguages: Set([item.originalLanguage.lowercased(), "ru", "en"]),
                voiceoverKinds: [.original, .dub]
            )
        }

        if item.primarySource == .internetArchive || item.externalIDs[.internetArchive] != nil {
            return PlayableSourceCapabilities(
                isPlayable: true,
                highestTier: .p720,
                audioLanguages: [item.originalLanguage.lowercased().nilIfEmpty ?? "en"],
                voiceoverKinds: [.original]
            )
        }

        let openStreams = OpenCinemaLibrary.streams(forItemID: item.id)
        let hasDirectEpisodes = item.seasons.contains { season in
            season.episodes.contains { $0.directStreamURL != nil }
        }

        guard !openStreams.isEmpty || hasDirectEpisodes else {
            return .none
        }

        let id = item.id
        let highestTier: VideoQualityTier = {
            if id.contains("his-girl-friday") || id.contains("apple-dolby") || id.contains("tears-of-steel") {
                return .p4K
            }
            if id.contains("cosmos-laundromat") {
                return .p1440
            }
            return .p1080
        }()

        var audioLangs: Set<String> = [item.originalLanguage.lowercased()]
        var kinds: Set<AudioVoiceoverKind> = [.original]

        if id.contains("angel-one") {
            audioLangs.formUnion(["en", "de", "fr", "es", "it"])
            kinds.insert(.dub)
        } else if id.contains("elephants-dream") || id.contains("apple-dolby") {
            audioLangs.formUnion(["en", "es", "de", "fr"])
            kinds.insert(.dub)
        }

        return PlayableSourceCapabilities(
            isPlayable: true,
            highestTier: highestTier,
            audioLanguages: audioLangs,
            voiceoverKinds: kinds
        )
    }

    public static func matchesAdvancedCriteria(
        item: MediaItem,
        criteria: CatalogFilterCriteria,
        userPlayableMediaIDs: Set<String> = []
    ) -> Bool {
        if criteria.maximumRating < 10.0 && item.displayRating > criteria.maximumRating {
            return false
        }

        if let personStudio = criteria.personOrStudioQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
           !personStudio.isEmpty {
            let needle = personStudio.normalizedForComparison
            let matchesDirector = item.director.normalizedForComparison.contains(needle)
            let matchesStudio = item.studio.normalizedForComparison.contains(needle)
            let matchesCastOrChar = item.cast.contains {
                $0.name.normalizedForComparison.contains(needle)
                    || $0.roleOrCharacter.normalizedForComparison.contains(needle)
            }
            if !matchesDirector && !matchesStudio && !matchesCastOrChar {
                return false
            }
        }

        if let availabilityStatus = criteria.availabilityStatus {
            let resolvedStatus = ContentAvailabilityResolver.quickStatus(
                for: item,
                userPlayableMediaIDs: userPlayableMediaIDs
            )
            if resolvedStatus != availabilityStatus {
                return false
            }
        }

        let needsSourceCheck = criteria.onlyAvailableToWatch
            || criteria.minimumVideoQuality != nil
            || criteria.requiredAudioLanguage != nil
            || criteria.requiredVoiceoverKind != nil

        guard needsSourceCheck else { return true }

        let caps = capabilities(for: item, userPlayableMediaIDs: userPlayableMediaIDs)
        if criteria.onlyAvailableToWatch && !caps.isPlayable {
            return false
        }

        if let minQuality = criteria.minimumVideoQuality, minQuality != .auto {
            guard caps.isPlayable,
                  caps.highestTier.resolutionPriorityRank >= minQuality.resolutionPriorityRank else {
                return false
            }
        }

        if let reqAudio = criteria.requiredAudioLanguage?.lowercased(), !reqAudio.isEmpty {
            let matchesOriginal = item.originalLanguage.lowercased() == reqAudio
            let matchesStreamAudio = caps.audioLanguages.contains(reqAudio)
            if criteria.onlyAvailableToWatch {
                if !caps.isPlayable || !matchesStreamAudio { return false }
            } else if !matchesOriginal && !matchesStreamAudio {
                return false
            }
        }

        if let reqKind = criteria.requiredVoiceoverKind {
            if reqKind == .original {
                return !criteria.onlyAvailableToWatch || caps.isPlayable
            }
            guard caps.isPlayable && caps.voiceoverKinds.contains(reqKind) else {
                return false
            }
        }

        return true
    }

    public static func matchesSearchQuery(_ item: MediaItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let normQ = trimmed.normalizedForComparison
        guard !normQ.isEmpty else { return true }

        if item.localizedTitle.normalizedForComparison.contains(normQ) { return true }
        if item.originalTitle.normalizedForComparison.contains(normQ) { return true }
        if item.alternativeTitles.contains(where: { $0.normalizedForComparison.contains(normQ) }) { return true }
        if item.director.normalizedForComparison.contains(normQ) { return true }
        if item.studio.normalizedForComparison.contains(normQ) { return true }
        if item.genres.contains(where: { $0.normalizedForComparison.contains(normQ) }) { return true }
        if item.releaseYear > 0 && String(item.releaseYear) == trimmed { return true }
        if item.cast.contains(where: {
            $0.name.normalizedForComparison.contains(normQ)
                || $0.roleOrCharacter.normalizedForComparison.contains(normQ)
        }) {
            return true
        }
        return false
    }
}
