import Foundation

public struct WikimediaVideoMatch: Sendable {
    public let fileTitle: String
    public let durationSeconds: TimeInterval
    public let primaryURL: URL
    public let primaryFormat: VideoStreamFormat
    public let qualities: [VideoQualityVariant]
    public let subtitles: [SubtitleTrackOption]
    public let originalLanguage: String
}

public protocol WikimediaCinemaServiceProtocol: Sendable {
    func resolveByFileTitle(_ fileTitle: String, originalLanguage: String) async throws -> WikimediaVideoMatch?
    func findFullLengthMatch(
        title: String,
        originalTitle: String,
        year: Int,
        expectedDurationMinutes: Int,
        isEpisodic: Bool,
        episodeTitle: String?,
        originalLanguage: String
    ) async throws -> WikimediaVideoMatch?
}

public final class WikimediaCinemaService: WikimediaCinemaServiceProtocol, @unchecked Sendable {
    private let httpClient: HTTPClient
    private let baseURL = URL.constant("https://commons.wikimedia.org")

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func resolveByFileTitle(_ fileTitle: String, originalLanguage: String = "en") async throws -> WikimediaVideoMatch? {
        let normalizedTitle = fileTitle.hasPrefix("File:") ? fileTitle : "File:\(fileTitle)"
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: "w/api.php",
            queryItems: [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "titles", value: normalizedTitle),
                URLQueryItem(name: "prop", value: "videoinfo"),
                URLQueryItem(name: "viprop", value: "url|size|mediatype|derivatives|timedtext|dimensions"),
                URLQueryItem(name: "format", value: "json")
            ],
            headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
            timeoutInterval: 10
        )
        let root = try await httpClient.send(endpoint, as: WikimediaQueryRootDTO.self)
        guard let page = root.query?.pages?.values.first(where: { $0.videoinfo?.isEmpty == false }),
              let info = page.videoinfo?.first else {
            return nil
        }
        return buildMatch(pageTitle: page.title ?? normalizedTitle, info: info, originalLanguage: originalLanguage)
    }

    public func findFullLengthMatch(
        title: String,
        originalTitle: String,
        year: Int,
        expectedDurationMinutes: Int,
        isEpisodic: Bool,
        episodeTitle: String?,
        originalLanguage: String
    ) async throws -> WikimediaVideoMatch? {
        let targetSearch: String
        if isEpisodic, let epTitle = episodeTitle?.nilIfEmpty, !epTitle.lowercased().hasPrefix("episode ") {
            targetSearch = "filetype:video \"\(epTitle)\""
        } else if year > 1900 && !isEpisodic {
            targetSearch = "filetype:video \"\(title)\" \(year)"
        } else {
            targetSearch = "filetype:video \"\(title)\""
        }

        let endpoint = Endpoint(
            baseURL: baseURL,
            path: "w/api.php",
            queryItems: [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "generator", value: "search"),
                URLQueryItem(name: "gsrsearch", value: targetSearch),
                URLQueryItem(name: "gsrnamespace", value: "6"),
                URLQueryItem(name: "gsrlimit", value: "6"),
                URLQueryItem(name: "prop", value: "videoinfo"),
                URLQueryItem(name: "viprop", value: "url|size|mediatype|derivatives|timedtext|dimensions"),
                URLQueryItem(name: "format", value: "json")
            ],
            headers: ["User-Agent": "CineVerse-iOS/2.0 (https://cineverse.app)"],
            timeoutInterval: 9
        )

        let root = try await httpClient.send(endpoint, as: WikimediaQueryRootDTO.self)
        let pages = Array(root.query?.pages?.values ?? [])
        let normTitle = title.normalizedForComparison
        let normOrig = originalTitle.normalizedForComparison
        let normEp = episodeTitle?.normalizedForComparison ?? ""

        // Minimum duration guard: NEVER accept short trailers or clips!
        let minDurationSeconds: Double = isEpisodic
            ? 300 // >= 5 minutes for episodes/shorts
            : max(Double(max(expectedDurationMinutes, 40)) * 60.0 * 0.65, 2400) // >= 40m or 65% of runtime for feature films

        let validCandidates = pages.compactMap { page -> (score: Int, match: WikimediaVideoMatch)? in
            guard let pageTitle = page.title,
                  let info = page.videoinfo?.first,
                  let duration = info.duration,
                  duration >= minDurationSeconds else {
                return nil
            }
            let lowerPage = pageTitle.lowercased()
            // Strictly reject trailers, clips, teasers, promos, end credits
            if lowerPage.contains("trailer") || lowerPage.contains("movie clip")
                || lowerPage.contains("teaser") || lowerPage.contains("end credits")
                || lowerPage.contains("promo") {
                return nil
            }

            let cleanPageNorm = pageTitle
                .replacingOccurrences(of: "File:", with: "")
                .normalizedForComparison

            let matchesMain = (!normTitle.isEmpty && cleanPageNorm.contains(normTitle))
                || (!normOrig.isEmpty && cleanPageNorm.contains(normOrig))
            let matchesEpisode = isEpisodic && !normEp.isEmpty && cleanPageNorm.contains(normEp)

            guard matchesMain || matchesEpisode else { return nil }
            guard let built = buildMatch(pageTitle: pageTitle, info: info, originalLanguage: originalLanguage) else {
                return nil
            }

            var score = Int(info.height ?? 0)
            if year > 1900 && pageTitle.contains(String(year)) { score += 500 }
            if matchesEpisode { score += 600 }
            return (score, built)
        }

        return validCandidates.sorted { $0.score > $1.score }.first?.match
    }

    private func buildMatch(
        pageTitle: String,
        info: WikimediaVideoInfoDTO,
        originalLanguage: String
    ) -> WikimediaVideoMatch? {
        var variantsByKey: [String: VideoQualityVariant] = [:]

        // 1. Native QuickTime (.mov) & WebM (.webm) & DASH (.mpd) derivatives
        for deriv in info.derivatives ?? [] {
            guard let src = deriv.src, src.hasPrefix("https://"), let url = URL(string: src) else { continue }
            let mime = (deriv.type ?? "").lowercased()
            let height = deriv.height ?? 360
            let width = deriv.width ?? 640
            let tier = VideoQualityTier.from(height: height)
            let format: VideoStreamFormat

            if mime.contains("quicktime") || mime.contains("mp4") || src.lowercased().hasSuffix(".mov") || src.lowercased().hasSuffix(".mp4") {
                format = .mp4
            } else if mime.contains("dash+xml") || src.lowercased().hasSuffix(".mpd") {
                format = .dash
            } else if mime.contains("webm") || src.lowercased().hasSuffix(".webm") {
                format = .webm
            } else {
                continue
            }

            let key = "\(tier.rawValue)|\(format.rawValue)"
            let bw = deriv.bandwidth
            let candidate = VideoQualityVariant(
                id: "wm-\(tier.rawValue)-\(format == .mp4 ? "mov" : (format == .dash ? "dash" : "webm"))",
                tier: tier,
                bandwidthBitsPerSecond: bw,
                width: width,
                height: height,
                variantStreamURL: url,
                variantFormat: format
            )
            if let existing = variantsByKey[key] {
                if (bw ?? 0) > (existing.bandwidthBitsPerSecond ?? 0) {
                    variantsByKey[key] = candidate
                }
            } else {
                variantsByKey[key] = candidate
            }
        }

        // 2. Include original master file if higher resolution (e.g. 2160p 4K or 1440p 2K WebM/MP4)
        if let origStr = info.url, origStr.hasPrefix("https://"),
           let origURL = URL(string: origStr),
           let origH = info.height, origH > 0 {
            let tier = VideoQualityTier.from(height: origH)
            let ext = origURL.pathExtension.lowercased()
            let fmt: VideoStreamFormat = (ext == "mp4" || ext == "mov" || ext == "m4v") ? .mp4 : .webm
            let key = "\(tier.rawValue)|\(fmt.rawValue)"
            if variantsByKey[key] == nil {
                variantsByKey[key] = VideoQualityVariant(
                    id: "wm-orig-\(tier.rawValue)",
                    tier: tier,
                    width: info.width,
                    height: origH,
                    variantStreamURL: origURL,
                    variantFormat: fmt
                )
            }
        }

        // Sort strictly by 4K -> 2K -> 1080p -> 720p -> 480p -> 360p, preferring native MP4/MOV on ties
        let sortedQualities = variantsByKey.values.sorted { lhs, rhs in
            if lhs.tier.resolutionPriorityRank != rhs.tier.resolutionPriorityRank {
                return lhs.tier.resolutionPriorityRank > rhs.tier.resolutionPriorityRank
            }
            if (lhs.variantFormat == .mp4) != (rhs.variantFormat == .mp4) {
                return lhs.variantFormat == .mp4
            }
            return (lhs.height ?? 0) > (rhs.height ?? 0)
        }

        guard let topVariant = sortedQualities.first,
              let primaryURL = topVariant.variantStreamURL else {
            return nil
        }

        // 3. Real WebVTT subtitle tracks (prioritizing ru, kk, en, ja, ko, zh)
        let priorityLangs: [String: Int] = ["ru": 0, "kk": 1, "en": 2, "ja": 3, "ko": 4, "zh": 5]
        let subtitles: [SubtitleTrackOption] = (info.timedtext ?? [])
            .compactMap { tt -> SubtitleTrackOption? in
                guard let src = tt.src, src.hasPrefix("https://"),
                      let url = URL(string: src),
                      let lang = tt.srclang?.nilIfEmpty else {
                    return nil
                }
                let display = LanguageCatalog.displayName(forLanguageCode: lang)
                return SubtitleTrackOption(
                    id: "wm-sub-\(lang)",
                    languageCode: lang,
                    displayName: display,
                    format: .webVTT,
                    externalURL: url
                )
            }
            .sorted { lhs, rhs in
                let pL = priorityLangs[lhs.languageCode.lowercased()] ?? 50
                let pR = priorityLangs[rhs.languageCode.lowercased()] ?? 50
                if pL != pR { return pL < pR }
                return lhs.displayName < rhs.displayName
            }

        return WikimediaVideoMatch(
            fileTitle: pageTitle,
            durationSeconds: info.duration ?? 0,
            primaryURL: primaryURL,
            primaryFormat: topVariant.variantFormat ?? .webm,
            qualities: sortedQualities,
            subtitles: subtitles,
            originalLanguage: originalLanguage
        )
    }
}

// MARK: - Wikimedia API DTOs

private struct WikimediaQueryRootDTO: Decodable, Sendable {
    let query: WikimediaQueryContainerDTO?
}

private struct WikimediaQueryContainerDTO: Decodable, Sendable {
    let pages: [String: WikimediaPageDTO]?
}

private struct WikimediaPageDTO: Decodable, Sendable {
    let title: String?
    let videoinfo: [WikimediaVideoInfoDTO]?
}

private struct WikimediaVideoInfoDTO: Decodable, Sendable {
    let url: String?
    let size: Int?
    let width: Int?
    let height: Int?
    let duration: Double?
    let mediatype: String?
    let derivatives: [WikimediaDerivativeDTO]?
    let timedtext: [WikimediaTimedTextDTO]?
}

private struct WikimediaDerivativeDTO: Decodable, Sendable {
    let src: String?
    let type: String?
    let shorttitle: String?
    let width: Int?
    let height: Int?
    let bandwidth: Int?
}

private struct WikimediaTimedTextDTO: Decodable, Sendable {
    let src: String?
    let type: String?
    let srclang: String?
    let label: String?
}
