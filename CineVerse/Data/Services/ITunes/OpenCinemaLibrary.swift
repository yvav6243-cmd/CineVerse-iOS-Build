import Foundation

public struct OpenCinemaStream: Sendable, Hashable {
    public let label: String
    public let url: URL
    public let note: String

    public init(label: String, url: URL, note: String) {
        self.label = label
        self.url = url
        self.note = note
    }
}

public enum OpenCinemaLibrary {
    public static let films: [(item: MediaItem, streams: [OpenCinemaStream])] = [
        (
            MediaItem(
                id: "opencinema:movie:open-tears-of-steel",
                externalIDs: [.openCinema: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "Tears of Steel (Open Cinema HD)",
                originalTitle: "Tears of Steel",
                synopsis: "In a dystopian future Amsterdam, a group of warriors and scientists gather at the Oude Kerk to stage a desperate mission to save the world from destructive robots. Full open-movie stream with adaptive HLS qualities and multi-language subtitles.",
                releaseYear: 2012,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "13+",
                genres: ["Sci-Fi", "Action"],
                durationMinutes: 12,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.8),
                popularityScore: 950,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Tos-poster.png/600px-Tos-poster.png"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Tos-poster.png/800px-Tos-poster.png"),
                director: "Ian Hubert (Blender Institute)"
            ),
            compactStreams([
                ("Adaptive HD · Unified Streaming", "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8", "Full-length Blender open sci-fi film with adaptive HLS bitrates")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-big-buck-bunny",
                externalIDs: [.openCinema: "https://d2zihajmogu5jn.cloudfront.net/big-buck-bunny/master.m3u8"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Big Buck Bunny (Full Animated Film)",
                originalTitle: "Big Buck Bunny",
                synopsis: "A gentle giant rabbit's peaceful morning in the sunlit forest is interrupted by three mischievous woodland bullies—until he devises an unforgettable comical payback. Full 1080p adaptive HLS open animated film.",
                releaseYear: 2008,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "6+",
                genres: ["Animation", "Comedy", "Family"],
                durationMinutes: 10,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.6),
                popularityScore: 920,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/600px-Big_buck_bunny_poster_big.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/800px-Big_buck_bunny_poster_big.jpg"),
                director: "Sacha Goedegebure (Blender Foundation)"
            ),
            compactStreams([
                ("Full HD 1080p · CDN 1", "https://d2zihajmogu5jn.cloudfront.net/big-buck-bunny/master.m3u8", "Adaptive 270p–1080p CloudFront HLS mirror"),
                ("Full HD · CDN 2", "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8", "Adaptive 180p–1080p Mux HLS mirror")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-apple-dolby-showcase",
                externalIDs: [.openCinema: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"],
                primarySource: .openCinema,
                projectType: .documentary,
                localizedTitle: "Cinema Mastering Showcase (Multi-Audio HLS)",
                originalTitle: "Apple Cinema Mastering Showcase",
                synopsis: "High-dynamic-range adaptive HLS cinema stream featuring multiple audio tracks and embedded subtitles for instant testing of CineVerse's pre-watch voiceover, quality, and subtitle selector.",
                releaseYear: 2024,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Documentary", "Sci-Fi"],
                durationMinutes: 5,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 8.4),
                popularityScore: 910,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/600px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/1024px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                director: "Cinema Engineering Team"
            ),
            compactStreams([
                ("4K UHD · Multi-Audio & Subs", "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8", "Adaptive up to 4K 2160p with multiple audio and subtitle tracks")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-sintel",
                externalIDs: [.openCinema: "https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Sintel (Open Animated Film)",
                originalTitle: "Sintel",
                synopsis: "A lonely young wanderer named Sintel searches across dangerous lands to rescue Scales, a baby dragon she befriended and lost. Acclaimed third open movie by the Blender Foundation.",
                releaseYear: 2010,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Animation", "Fantasy", "Adventure"],
                durationMinutes: 15,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.5),
                popularityScore: 900,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/8/8f/Sintel_poster.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/8/8f/Sintel_poster.jpg"),
                director: "Colin Levy (Blender Foundation)"
            ),
            compactStreams([
                ("Adaptive HLS · CloudFront", "https://d2zihajmogu5jn.cloudfront.net/sintel/master.m3u8", "Full-length adaptive HLS stream (7 quality variants)")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-elephants-dream",
                externalIDs: [.openCinema: "https://d2zihajmogu5jn.cloudfront.net/elephantsdream/hls/ed_hd.m3u8"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Elephants Dream (Full Animated Film)",
                originalTitle: "Elephants Dream",
                synopsis: "Two strangers, Proog and Emo, navigate an ever-shifting surreal mechanical world shaped by their own conflicting perceptions. The world's first open animated short film.",
                releaseYear: 2006,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Animation", "Sci-Fi", "Mystery"],
                durationMinutes: 11,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.2),
                popularityScore: 890,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e8/Elephants_Dream_s5_both.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e8/Elephants_Dream_s5_both.jpg"),
                director: "Bassam Kurdali (Orange Open Movie Project)"
            ),
            compactStreams([
                ("Full HD 1080p · Multi-Audio & Subs", "https://d2zihajmogu5jn.cloudfront.net/elephantsdream/hls/ed_hd.m3u8", "270p–1080p with 4 audio tracks and 5 subtitle languages"),
                ("HD 720p · Mirror CDN", "https://playertest.longtailvideo.com/adaptive/elephants_dream_v4/index.m3u8", "Alternative adaptive mirror with multi-audio & subtitles")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-angel-one",
                externalIDs: [.openCinema: "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8"],
                primarySource: .openCinema,
                projectType: .special,
                localizedTitle: "Angel One (Multi-Language Sci-Fi Clip)",
                originalTitle: "Angel One",
                synopsis: "Open adaptive sci-fi special curated for testing multi-language voiceover switching and synchronized subtitle tracks directly inside the CineVerse player.",
                releaseYear: 2016,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Sci-Fi", "Action"],
                durationMinutes: 2,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.4),
                popularityScore: 870,
                posterURL: nil,
                backdropURL: nil,
                director: "Shaka Open Media Project"
            ),
            compactStreams([
                ("Multi-Audio & Subs · HLS", "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8", "6 audio language tracks and 4 subtitle tracks")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-bipbop-advanced",
                externalIDs: [.openCinema: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"],
                primarySource: .openCinema,
                projectType: .special,
                localizedTitle: "BipBop Reference fMP4 (1080p Multi-Audio)",
                originalTitle: "Apple BipBop Advanced Reference",
                synopsis: "Reference fMP4 HTTP Live Streaming test presentation with 270p–1080p video tiers, stereo and surround audio renditions, and subtitle tracks.",
                releaseYear: 2020,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "G",
                genres: ["Documentary", "Special"],
                durationMinutes: 30,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.1),
                popularityScore: 860,
                posterURL: nil,
                backdropURL: nil,
                director: "Apple HTTP Live Streaming Team"
            ),
            compactStreams([
                ("Full HD 1080p · fMP4 HLS", "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8", "270p–1080p adaptive fMP4 with multi-audio tracks")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-bipbop-16x9",
                externalIDs: [.openCinema: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"],
                primarySource: .openCinema,
                projectType: .special,
                localizedTitle: "BipBop 16:9 Cinema Stream (8 Subtitles)",
                originalTitle: "Apple BipBop 16:9 Variant",
                synopsis: "Widescreen 16:9 adaptive cinema calibration stream featuring multiple quality tiers from 234p to 1080p, dual audio tracks, and 8 multilingual subtitle tracks.",
                releaseYear: 2019,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "G",
                genres: ["Documentary", "Special"],
                durationMinutes: 30,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.0),
                popularityScore: 850,
                posterURL: nil,
                backdropURL: nil,
                director: "Apple HTTP Live Streaming Team"
            ),
            compactStreams([
                ("Full HD 1080p · 8 Subtitles", "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8", "Adaptive 234p–1080p with 8 subtitle tracks")
            ])
        )
    ]

    public static var items: [MediaItem] {
        films.map(\.item)
    }

    public static func streams(forItemID id: String) -> [OpenCinemaStream] {
        let normalizedID = id.hasPrefix("opencinema:") ? id : "opencinema:movie:\(id)"
        return films.first(where: { $0.item.id == normalizedID })?.streams ?? []
    }

    private static func compactStreams(_ specs: [(label: String, urlString: String, note: String)]) -> [OpenCinemaStream] {
        specs.compactMap { spec in
            guard let url = URL(string: spec.urlString) else { return nil }
            return OpenCinemaStream(label: spec.label, url: url, note: spec.note)
        }
    }
}
