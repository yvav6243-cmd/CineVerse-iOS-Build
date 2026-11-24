import Foundation

public extension TMDBMapper {
    static let imageBase = "https://image.tmdb.org/t/p/"

    static let genreNamesByID: [Int: String] = [
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10751: "Family",
        14: "Fantasy",
        36: "History",
        27: "Horror",
        10402: "Music",
        9648: "Mystery",
        10749: "Romance",
        878: "Sci-Fi",
        10770: "TV Movie",
        53: "Thriller",
        10752: "War",
        37: "Western",
        10759: "Action & Adventure",
        10762: "Kids",
        10763: "News",
        10764: "Reality",
        10765: "Sci-Fi & Fantasy",
        10766: "Soap",
        10767: "Talk",
        10768: "War & Politics"
    ]

    static func genreID(for name: String) -> Int? {
        let lower = name.lowercased()
        return genreNamesByID.first { $0.value.lowercased() == lower }?.key
    }

    static func imageURL(path: String?, size: String = "w500") -> URL? {
        guard let path = path?.nilIfEmpty else { return nil }
        return URL(string: "\(imageBase)\(size)\(path)")
    }

    static func classifyMovie(genreIDs: [Int], originalLanguage: String) -> MediaProjectType {
        if genreIDs.contains(16) {
            return originalLanguage == "ja" ? .animeMovie : .cartoonMovie
        }
        if genreIDs.contains(99) {
            return .documentary
        }
        return .movie
    }

    static func classifyTV(
        genreIDs: [Int],
        originalLanguage: String,
        origins: [String],
        tmdbType: String?
    ) -> MediaProjectType {
        if genreIDs.contains(16) {
            return originalLanguage == "ja" ? .anime : .cartoonSeries
        }
        if genreIDs.contains(99) {
            return .documentary
        }
        let dramaOrigins: Set<String> = ["KR", "CN", "TW", "TH", "JP"]
        if genreIDs.contains(18) && origins.contains(where: { dramaOrigins.contains($0) }) {
            return .drama
        }
        if let tmdbType {
            let lowered = tmdbType.lowercased()
            if lowered == "reality" || lowered == "talk show" || lowered == "news" || lowered == "video" {
                return .other
            }
        }
        return .tvSeries
    }

    static func mapCast(_ cast: [TMDBCastMemberDTO]) -> [MediaCreditPerson] {
        cast.prefix(16).map { member in
            MediaCreditPerson(
                id: "tmdb:person:\(member.id)",
                name: member.name,
                roleOrCharacter: member.character?.nilIfEmpty ?? "Cast",
                department: "Acting",
                profileImageURL: imageURL(path: member.profilePath, size: "w185")
            )
        }
    }

    static func extractTrailerURL(from videos: [TMDBVideoDTO]) -> URL? {
        let sorted = videos.sorted { lhs, rhs in
            let lhsScore = (lhs.official == true ? 2 : 0) + (lhs.type == "Trailer" ? 2 : 0)
            let rhsScore = (rhs.official == true ? 2 : 0) + (rhs.type == "Trailer" ? 2 : 0)
            return lhsScore > rhsScore
        }
        guard let best = sorted.first(where: { $0.site.lowercased() == "youtube" }) else {
            return nil
        }
        return URL(string: "https://www.youtube.com/watch?v=\(best.key)")
    }

    static func extractMovieCertification(_ container: TMDBReleaseDatesContainerDTO?, region: String) -> String? {
        guard let entries = container?.results else { return nil }
        let preferred = entries.first(where: { $0.iso31661 == region })
            ?? entries.first(where: { $0.iso31661 == "US" })
            ?? entries.first
        return preferred?.releaseDates?.compactMap { $0.certification?.nilIfEmpty }.first
    }

    static func extractTVContentRating(_ container: TMDBContentRatingsContainerDTO?, region: String) -> String? {
        guard let entries = container?.results else { return nil }
        let preferred = entries.first(where: { $0.iso31661 == region })
            ?? entries.first(where: { $0.iso31661 == "US" })
            ?? entries.first
        return preferred?.rating.nilIfEmpty
    }

    static func extractWatchProviderLinks(_ container: TMDBWatchProvidersContainerDTO?, region: String) -> [ExternalOfficialPlatformLink] {
        guard let results = container?.results else { return [] }
        let regional = results[region] ?? results["US"] ?? results.values.first
        guard let regional,
              let linkString = regional.link,
              let linkURL = URL(string: linkString),
              linkURL.scheme?.lowercased() == "https" else {
            return []
        }

        let providers = (regional.flatrate ?? []) + (regional.free ?? []) + (regional.rent ?? []) + (regional.buy ?? [])
        var seen: Set<Int> = []
        var links: [ExternalOfficialPlatformLink] = []
        for provider in providers where seen.insert(provider.providerId).inserted {
            links.append(
                ExternalOfficialPlatformLink(
                    id: "tmdb-provider-\(provider.providerId)",
                    siteName: provider.providerName,
                    url: linkURL,
                    languageCode: nil
                )
            )
        }
        return links
    }

    static func mapMovieStatus(_ raw: String?) -> MediaReleaseStatus {
        switch raw?.lowercased() {
        case "planned", "in production", "post production", "rumored":
            return .upcoming
        case "canceled":
            return .cancelled
        default:
            return .finished
        }
    }

    static func mapTVStatus(_ raw: String?) -> MediaReleaseStatus {
        switch raw?.lowercased() {
        case "returning series":
            return .releasing
        case "ended":
            return .finished
        case "canceled":
            return .cancelled
        case "in production", "planned", "pilot":
            return .upcoming
        default:
            return .hiatus
        }
    }

    static func extractYear(from rawDate: String?, date: Date?) -> Int {
        if let rawDate, rawDate.count >= 4, let year = Int(rawDate.prefix(4)) {
            return year
        }
        if let date {
            return Calendar.current.component(.year, from: date)
        }
        return 0
    }
}
