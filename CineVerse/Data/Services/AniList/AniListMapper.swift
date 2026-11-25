import Foundation

public enum AniListMapper {
    public static func mapMedia(_ dto: AniListMediaDTO) -> MediaItem {
        let projectType = mapProjectType(dto.format)
        let localizedTitle = dto.title?.english?.nilIfEmpty
            ?? dto.title?.romaji?.nilIfEmpty
            ?? dto.title?.native?.nilIfEmpty
            ?? "Untitled Anime"
        let originalTitle = dto.title?.native?.nilIfEmpty
            ?? dto.title?.romaji?.nilIfEmpty
            ?? localizedTitle

        let score10: Double? = dto.averageScore.map { Double($0) / 10.0 }
        let releaseDate = makeDate(from: dto.startDate)
        let year = dto.seasonYear ?? dto.startDate?.year ?? 0
        let episodeDuration = dto.duration ?? (projectType.isEpisodic ? 24 : 95)
        let totalEps = max(dto.episodes ?? (projectType.isEpisodic ? 12 : 1), 1)
        let ref = MediaReference(provider: .aniList, kind: .anime, providerID: String(dto.id))

        let studioName = dto.studios?.nodes?.compactMap { $0.name?.nilIfEmpty }.first ?? ""
        let director = dto.staff?.edges?
            .first(where: { $0.role?.lowercased().contains("director") == true })?
            .node?.name?.full
            ?? studioName.nilIfEmpty
            ?? "Animation Studio"
        let altTitles: [String] = Array(Set(
            ([dto.title?.romaji, dto.title?.english, dto.title?.native].compactMap { $0?.nilIfEmpty } + (dto.synonyms ?? []))
                .filter { $0 != localizedTitle && $0 != originalTitle }
        )).sorted()

        let cast: [MediaCreditPerson] = (dto.characters?.edges ?? []).enumerated().compactMap { index, edge in
            guard let charName = edge.node?.name?.full else { return nil }
            let vaName = edge.voiceActors?.first?.name?.full
            let roleText = vaName != nil ? "\(charName) (CV: \(vaName ?? ""))" : charName
            return MediaCreditPerson(
                id: "anilist:char:\(dto.id):\(index)",
                name: charName,
                roleOrCharacter: roleText,
                department: "Voice",
                profileImageURL: edge.node?.image?.medium.flatMap(URL.init(string:))
            )
        }

        let trailerURL: URL? = {
            guard let trailer = dto.trailer,
                  let site = trailer.site?.lowercased(),
                  let id = trailer.id else { return nil }
            if site == "youtube" {
                return URL(string: "https://www.youtube.com/watch?v=\(id)")
            } else if site == "dailymotion" {
                return URL(string: "https://www.dailymotion.com/video/\(id)")
            }
            return nil
        }()

        let officialLinks: [ExternalOfficialPlatformLink] = (dto.externalLinks ?? [])
            .filter { $0.type?.uppercased() == "STREAMING" }
            .enumerated()
            .compactMap { index, link in
                guard let site = link.site,
                      let rawURL = link.url,
                      let url = URL(string: rawURL),
                      url.scheme?.lowercased() == "https" else {
                    return nil
                }
                return ExternalOfficialPlatformLink(
                    id: "anilist-link-\(dto.id)-\(index)",
                    siteName: site,
                    url: url,
                    languageCode: link.language
                )
            }

        let similarIDs: [String] = (dto.recommendations?.nodes ?? [])
            .compactMap { $0.mediaRecommendation }
            .map { MediaReference(provider: .aniList, kind: .anime, providerID: String($0.id)).id }

        let seasons = buildSeasons(from: dto, totalEpisodes: totalEps, durationMinutes: episodeDuration)
        let nextAirDate = dto.nextAiringEpisode.map { Date(timeIntervalSince1970: TimeInterval($0.airingAt)) }

        var externalIDs: [MetadataProviderSource: String] = [.aniList: String(dto.id)]
        if let idMal = dto.idMal {
            externalIDs[.openCinema] = "mal:\(idMal)"
        }

        return MediaItem(
            id: ref.id,
            externalIDs: externalIDs,
            primarySource: .aniList,
            projectType: projectType,
            localizedTitle: localizedTitle,
            originalTitle: originalTitle,
            synopsis: (dto.description ?? "").strippedHTML.nilIfEmpty ?? "No description available.",
            releaseYear: year,
            releaseDate: releaseDate,
            countryOfOrigin: dto.countryOfOrigin ?? "JP",
            originalLanguage: originalLanguage(forCountry: dto.countryOfOrigin),
            ageRating: dto.isAdult == true ? "18+" : "13+",
            genres: dto.genres ?? [],
            durationMinutes: episodeDuration,
            totalSeasons: 1,
            totalEpisodes: totalEps,
            releaseStatus: mapStatus(dto.status),
            ratings: MultiSourceRatings(aniListScore: score10),
            popularityScore: Double(dto.popularity ?? 0),
            posterURL: dto.coverImage?.extraLarge.flatMap(URL.init(string:)),
            backdropURL: dto.bannerImage.flatMap(URL.init(string:)) ?? dto.coverImage?.extraLarge.flatMap(URL.init(string:)),
            bannerAccentHex: dto.coverImage?.color,
            director: director,
            studio: studioName,
            alternativeTitles: altTitles,
            cast: cast,
            seasons: seasons,
            trailerURL: trailerURL,
            officialPlatformLinks: officialLinks,
            similarProjectIDs: similarIDs,
            nextAiringEpisodeNumber: dto.nextAiringEpisode?.episode,
            nextAiringDate: nextAirDate
        )
    }

    public static func mapAiringEvent(_ schedule: AniListAiringScheduleDTO) -> PremiereEvent? {
        guard let media = schedule.media, media.isAdult != true else { return nil }
        let mapped = mapMedia(media)
        guard let ref = mapped.reference else { return nil }
        return PremiereEvent(
            id: "anilist:air:\(media.id):\(schedule.episode)",
            mediaReference: ref,
            title: mapped.localizedTitle,
            episodeTitle: "Episode \(schedule.episode)",
            posterURL: mapped.posterURL,
            date: Date(timeIntervalSince1970: TimeInterval(schedule.airingAt)),
            episodeNumber: schedule.episode,
            seasonNumber: 1,
            kind: mapped.projectType,
            source: .aniList
        )
    }

    private static func buildSeasons(
        from dto: AniListMediaDTO,
        totalEpisodes: Int,
        durationMinutes: Int
    ) -> [MediaSeason] {
        guard mapProjectType(dto.format).isEpisodic else { return [] }
        let streaming = (dto.streamingEpisodes ?? []).filter { ep in
            let lowered = (ep.title ?? "").lowercased()
            return !lowered.contains("trailer")
                && !lowered.contains("teaser")
                && !lowered.hasPrefix("pv ")
                && lowered != "pv"
        }
        let count = max(totalEpisodes, streaming.count)
        var episodes: [MediaEpisode] = []
        episodes.reserveCapacity(count)

        for number in 1...min(count, 200) {
            let streamInfo = streaming[safe: number - 1]
            let title = streamInfo?.title?.nilIfEmpty ?? "Episode \(number)"
            let thumb = streamInfo?.thumbnail.flatMap(URL.init(string:))
            episodes.append(
                MediaEpisode(
                    id: "anilist:anime:\(dto.id):s1:e\(number)",
                    seasonNumber: 1,
                    episodeNumber: number,
                    title: title,
                    originalTitle: nil,
                    synopsis: "Episode \(number) of \(dto.title?.english ?? dto.title?.romaji ?? "this series").",
                    durationMinutes: durationMinutes,
                    airDate: nil,
                    stillImageURL: thumb
                )
            )
        }

        return [
            MediaSeason(
                id: "anilist:anime:\(dto.id):s1",
                seasonNumber: 1,
                title: "Episodes",
                overview: "",
                episodeCount: count,
                posterURL: dto.coverImage?.extraLarge.flatMap(URL.init(string:)),
                releaseYear: dto.seasonYear,
                episodes: episodes
            )
        ]
    }

    private static func mapProjectType(_ format: String?) -> MediaProjectType {
        switch format?.uppercased() {
        case "MOVIE":
            return .animeMovie
        case "OVA", "SPECIAL", "MUSIC":
            return .special
        default:
            return .anime
        }
    }

    private static func mapStatus(_ status: String?) -> MediaReleaseStatus {
        switch status?.uppercased() {
        case "RELEASING":
            return .releasing
        case "FINISHED":
            return .finished
        case "NOT_YET_RELEASED":
            return .upcoming
        case "HIATUS":
            return .hiatus
        case "CANCELLED":
            return .cancelled
        default:
            return .finished
        }
    }

    private static func originalLanguage(forCountry country: String?) -> String {
        switch country?.uppercased() {
        case "CN": return "zh"
        case "KR": return "ko"
        case "TW": return "zh"
        default: return "ja"
        }
    }

    private static func makeDate(from dto: AniListDateDTO?) -> Date? {
        guard let year = dto?.year else { return nil }
        let month = dto?.month ?? 1
        let day = dto?.day ?? 1
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)
    }
}
