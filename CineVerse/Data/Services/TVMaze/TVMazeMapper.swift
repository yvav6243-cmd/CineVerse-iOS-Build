import Foundation

public enum TVMazeMapper {
    public static func mapShow(_ dto: TVMazeShowDTO) -> MediaItem {
        let ref = MediaReference(provider: .tvMaze, kind: .tv, providerID: String(dto.id))
        let releaseDate = dto.premiered.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        let year = dto.premiered.flatMap { Int($0.prefix(4)) } ?? 0
        let country = dto.network?.country?.code ?? dto.webChannel?.country?.code ?? "US"
        let origLang = languageCode(from: dto.language)
        let projectType = classifyShow(type: dto.type, genres: dto.genres ?? [], language: origLang)

        let posterURL = httpsURL(from: dto.image?.original ?? dto.image?.medium)
        let backdropURL = httpsURL(from: dto.image?.original ?? dto.image?.medium)
        let duration = dto.averageRuntime ?? dto.runtime ?? 42

        let cast: [MediaCreditPerson] = (dto.embedded?.cast ?? []).prefix(16).map { member in
            MediaCreditPerson(
                id: "tvmaze:person:\(member.person.id)",
                name: member.person.name,
                roleOrCharacter: member.character?.name ?? "Cast",
                department: "Acting",
                profileImageURL: httpsURL(from: member.person.image?.medium)
            )
        }

        let embeddedEpisodes = dto.embedded?.episodes ?? []
        let embeddedSeasons = dto.embedded?.seasons ?? []
        let mappedSeasons: [MediaSeason] = embeddedSeasons
            .filter { $0.number > 0 }
            .sorted { $0.number < $1.number }
            .map { season in
                let eps = embeddedEpisodes
                    .filter { $0.season == season.number }
                    .compactMap { mapEpisode($0, showID: dto.id, fallbackDuration: duration) }
                return MediaSeason(
                    id: "tvmaze:tv:\(dto.id):s\(season.number)",
                    seasonNumber: season.number,
                    title: season.name?.nilIfEmpty ?? "Season \(season.number)",
                    overview: (season.summary ?? "").strippedHTML,
                    episodeCount: max(season.episodeOrder ?? eps.count, eps.count),
                    posterURL: httpsURL(from: season.image?.medium),
                    releaseYear: season.premiereDate.flatMap { Int($0.prefix(4)) },
                    episodes: eps
                )
            }

        var officialLinks: [ExternalOfficialPlatformLink] = []
        if let officialSite = dto.officialSite, let url = httpsURL(from: officialSite) {
            let siteName = dto.webChannel?.name ?? dto.network?.name ?? "Official Site"
            officialLinks.append(
                ExternalOfficialPlatformLink(
                    id: "tvmaze-official-\(dto.id)",
                    siteName: siteName,
                    url: url
                )
            )
        } else if let webSite = dto.webChannel?.officialSite, let url = httpsURL(from: webSite) {
            officialLinks.append(
                ExternalOfficialPlatformLink(
                    id: "tvmaze-web-\(dto.id)",
                    siteName: dto.webChannel?.name ?? "Streaming Platform",
                    url: url
                )
            )
        }

        let totalEps = max(embeddedEpisodes.count, mappedSeasons.reduce(0) { $0 + $1.episodeCount }, 1)

        return MediaItem(
            id: ref.id,
            externalIDs: [.tvMaze: String(dto.id)],
            primarySource: .tvMaze,
            projectType: projectType,
            localizedTitle: dto.name,
            originalTitle: dto.name,
            synopsis: (dto.summary ?? "").strippedHTML.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: country,
            originalLanguage: origLang,
            ageRating: "16+",
            genres: dto.genres ?? [],
            durationMinutes: duration,
            totalSeasons: max(mappedSeasons.count, 1),
            totalEpisodes: totalEps,
            releaseStatus: mapStatus(dto.status),
            ratings: MultiSourceRatings(),
            popularityScore: Double(dto.weight ?? 0),
            posterURL: posterURL,
            backdropURL: backdropURL,
            director: dto.network?.name ?? dto.webChannel?.name ?? "Network Production",
            cast: cast,
            seasons: mappedSeasons,
            officialPlatformLinks: officialLinks
        )
    }

    public static func mapEpisode(_ dto: TVMazeEpisodeDTO, showID: Int, fallbackDuration: Int) -> MediaEpisode? {
        guard let season = dto.season, let number = dto.number else { return nil }
        let airDate = dto.airdate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        return MediaEpisode(
            id: "tvmaze:tv:\(showID):s\(season):e\(number)",
            seasonNumber: season,
            episodeNumber: number,
            title: dto.name?.nilIfEmpty ?? "Episode \(number)",
            synopsis: (dto.summary ?? "").strippedHTML.nilIfEmpty ?? "No episode description available.",
            durationMinutes: dto.runtime ?? fallbackDuration,
            airDate: airDate,
            stillImageURL: httpsURL(from: dto.image?.medium)
        )
    }

    public static func mapScheduleEntry(_ entry: TVMazeScheduleEntryDTO) -> PremiereEvent? {
        guard let show = entry.show ?? entry.embedded?.show else { return nil }
        let mapped = mapShow(show)
        guard let ref = mapped.reference else { return nil }
        let date: Date? = {
            if let stamp = entry.airstamp {
                return ISO8601DateFormatter().date(from: stamp)
            }
            return entry.airdate.flatMap { CineVerseDateFormatters.isoDateParser.date(from: $0) }
        }()
        guard let date else { return nil }

        return PremiereEvent(
            id: "tvmaze:air:\(show.id):\(entry.id)",
            mediaReference: ref,
            title: show.name,
            episodeTitle: entry.name,
            posterURL: mapped.posterURL,
            date: date,
            episodeNumber: entry.number,
            seasonNumber: entry.season,
            kind: mapped.projectType,
            source: .tvMaze
        )
    }

    private static func classifyShow(type: String?, genres: [String], language: String) -> MediaProjectType {
        let loweredType = type?.lowercased() ?? ""
        let loweredGenres = Set(genres.map { $0.lowercased() })
        if loweredType == "animation" || loweredGenres.contains("anime") {
            return language == "ja" ? .anime : .cartoonSeries
        }
        if loweredType == "documentary" {
            return .documentary
        }
        if loweredType == "reality" || loweredType == "talk show" || loweredType == "variety" || loweredType == "news" {
            return .other
        }
        return .tvSeries
    }

    private static func mapStatus(_ raw: String?) -> MediaReleaseStatus {
        switch raw?.lowercased() {
        case "running": return .releasing
        case "ended": return .finished
        case "in development", "to be determined": return .upcoming
        default: return .finished
        }
    }

    private static func languageCode(from name: String?) -> String {
        switch name?.lowercased() {
        case "japanese": return "ja"
        case "korean": return "ko"
        case "russian": return "ru"
        case "french": return "fr"
        case "german": return "de"
        case "spanish": return "es"
        case "chinese": return "zh"
        default: return "en"
        }
    }

    private static func httpsURL(from raw: String?) -> URL? {
        guard let raw = raw?.nilIfEmpty else { return nil }
        if raw.hasPrefix("http://") {
            return URL(string: "https://" + raw.dropFirst("http://".count))
        }
        return URL(string: raw)
    }
}

public struct TVMazeShowWithScore: Sendable {
    public let item: MediaItem
    public let rating: Double?
}

public extension TVMazeMapper {
    static func mapShowWithRating(_ dto: TVMazeShowDTO, averageRating: Double?) -> MediaItem {
        var item = mapShow(dto)
        item.ratings.tvMazeScore = averageRating
        return item
    }
}
