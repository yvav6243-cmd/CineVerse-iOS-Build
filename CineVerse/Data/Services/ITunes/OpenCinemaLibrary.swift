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
                id: "opencinema:movie:open-apple-dolby-showcase",
                externalIDs: [.openCinema: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"],
                primarySource: .openCinema,
                projectType: .documentary,
                localizedTitle: "Cinema Mastering 4K Showcase (Multi-Audio HLS)",
                originalTitle: "Apple Cinema Mastering Showcase",
                synopsis: "4K 2160p UHD & 1440p 2K QHD adaptive HLS cinema stream featuring multiple real voiceover audio tracks and embedded multilingual subtitles.",
                releaseYear: 2024,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Documentary", "Sci-Fi"],
                durationMinutes: 5,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 8.4),
                popularityScore: 995,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/600px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg/1024px-Everest_North_Face_toward_Base_Camp_Tibet_Luca_Galuzzi_2006.jpg"),
                director: "Cinema Engineering Team"
            ),
            compactStreams([
                ("4K UHD & 2K · Multi-Audio & Subs", "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8", "True 2160p 4K & 1440p 2K native AVPlayer HLS with multi-language audio and subtitles")
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
                synopsis: "A gentle giant rabbit's peaceful morning in the sunlit forest is interrupted by three mischievous woodland bullies—until he devises an unforgettable comical payback.",
                releaseYear: 2008,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "6+",
                genres: ["Animation", "Comedy", "Family"],
                durationMinutes: 10,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.6),
                popularityScore: 990,
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
                id: "opencinema:movie:open-tears-of-steel",
                externalIDs: [.openCinema: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "Tears of Steel (Open Cinema HD)",
                originalTitle: "Tears of Steel",
                synopsis: "In a dystopian future Amsterdam, a group of warriors and scientists gather at the Oude Kerk to stage a desperate mission to save the world from destructive robots.",
                releaseYear: 2012,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "13+",
                genres: ["Sci-Fi", "Action"],
                durationMinutes: 12,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.8),
                popularityScore: 985,
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
                id: "opencinema:movie:open-elephants-dream",
                externalIDs: [.openCinema: "https://d2zihajmogu5jn.cloudfront.net/elephantsdream/hls/ed_hd.m3u8"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Elephants Dream (Multi-Audio Animated Film)",
                originalTitle: "Elephants Dream",
                synopsis: "Two strangers, Proog and Emo, navigate an ever-shifting surreal mechanical world shaped by their own conflicting perceptions.",
                releaseYear: 2006,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Animation", "Sci-Fi", "Mystery"],
                durationMinutes: 11,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.2),
                popularityScore: 980,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e8/Elephants_Dream_s5_both.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e8/Elephants_Dream_s5_both.jpg"),
                director: "Bassam Kurdali (Orange Open Movie Project)"
            ),
            compactStreams([
                ("Full HD 1080p · 4 Audio & 5 Subs", "https://d2zihajmogu5jn.cloudfront.net/elephantsdream/hls/ed_hd.m3u8", "270p–1080p with 4 audio tracks and 5 subtitle languages"),
                ("HD 720p · Mirror CDN", "https://playertest.longtailvideo.com/adaptive/elephants_dream_v4/index.m3u8", "Alternative adaptive mirror with multi-audio & subtitles")
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
                synopsis: "A lonely young wanderer named Sintel searches across dangerous lands to rescue Scales, a baby dragon she befriended and lost.",
                releaseYear: 2010,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Animation", "Fantasy", "Adventure"],
                durationMinutes: 15,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.5),
                popularityScore: 975,
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
                id: "opencinema:movie:open-angel-one",
                externalIDs: [.openCinema: "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8"],
                primarySource: .openCinema,
                projectType: .special,
                localizedTitle: "Angel One (6 Voiceover Languages)",
                originalTitle: "Angel One",
                synopsis: "Open adaptive sci-fi special featuring 6 real dubbed audio tracks (English, German, French, Spanish, Italian) and 4 subtitle tracks.",
                releaseYear: 2016,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Sci-Fi", "Action"],
                durationMinutes: 2,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.4),
                popularityScore: 970,
                posterURL: nil,
                backdropURL: nil,
                director: "Shaka Open Media Project"
            ),
            compactStreams([
                ("Multi-Voiceover Dubs · HLS", "https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8", "6 real audio language tracks and 4 subtitle tracks")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-his-girl-friday",
                externalIDs: [.openCinema: "wmfile:File:His Girl Friday (1940, SDR).webm"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "His Girl Friday (4K UHD Full Movie)",
                originalTitle: "His Girl Friday",
                synopsis: "Newspaper editor Walter Burns discovers his star reporter and ex-wife Hildy Johnson is engaged to remarry—launching a razor-sharp rapid-fire comedy to keep her on the story of a lifetime. Restored 2160p 4K UHD public-domain feature film.",
                releaseYear: 1940,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "PG",
                genres: ["Comedy", "Drama", "Romance"],
                durationMinutes: 92,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.9),
                popularityScore: 960,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/His_Girl_Friday_%281940%2C_SDR%29.webm/960px-His_Girl_Friday_%281940%2C_SDR%29.webm.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/His_Girl_Friday_%281940%2C_SDR%29.webm/960px-His_Girl_Friday_%281940%2C_SDR%29.webm.jpg"),
                director: "Howard Hawks"
            ),
            compactStreams([
                ("4K UHD (2160p) · Full Feature Film", "https://upload.wikimedia.org/wikipedia/commons/2/24/His_Girl_Friday_%281940%2C_SDR%29.webm", "Full 92-minute feature film in 2960×2160 4K UHD")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-charade-1963",
                externalIDs: [.openCinema: "wmfile:File:Charade (Stanley Donen, 1963).webm"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "Charade (Full HD Feature Film)",
                originalTitle: "Charade",
                synopsis: "Romance and suspense ensue in Paris as a woman is pursued by several men who want a fortune her murdered husband had stolen. Full 113-minute thriller starring Cary Grant and Audrey Hepburn.",
                releaseYear: 1963,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "13+",
                genres: ["Thriller", "Mystery", "Romance"],
                durationMinutes: 113,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.9),
                popularityScore: 955,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Charade_%28Stanley_Donen%2C_1963%29.webm/960px-Charade_%28Stanley_Donen%2C_1963%29.webm.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Charade_%28Stanley_Donen%2C_1963%29.webm/960px-Charade_%28Stanley_Donen%2C_1963%29.webm.jpg"),
                director: "Stanley Donen"
            ),
            compactStreams([
                ("1080p Full HD · Complete Film", "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/ef/Charade_%28Stanley_Donen%2C_1963%29.webm/Charade_%28Stanley_Donen%2C_1963%29.webm.1080p.vp9.webm", "Complete 113-minute feature film with multilingual subtitles"),
                ("360p Native AVPlayer · QuickTime", "https://upload.wikimedia.org/wikipedia/commons/transcoded/e/ef/Charade_%28Stanley_Donen%2C_1963%29.webm/Charade_%28Stanley_Donen%2C_1963%29.webm.360p.mpeg4.mov", "Hardware AVPlayer stream with PiP & AirPlay")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-night-living-dead",
                externalIDs: [.openCinema: "wmfile:File:Night of the Living Dead (1968).webm"],
                primarySource: .openCinema,
                projectType: .movie,
                localizedTitle: "Night of the Living Dead (1080p Full Film)",
                originalTitle: "Night of the Living Dead",
                synopsis: "A ragtag group of Pennsylvanians barricade themselves in an old farmhouse to remain safe from a bloodthirsty flesh-eating breed of monsters. Complete 96-minute landmark horror classic.",
                releaseYear: 1968,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "16+",
                genres: ["Horror", "Thriller"],
                durationMinutes: 96,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.8),
                popularityScore: 950,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Night_of_the_Living_Dead_%281968%29.webm/960px-Night_of_the_Living_Dead_%281968%29.webm.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Night_of_the_Living_Dead_%281968%29.webm/960px-Night_of_the_Living_Dead_%281968%29.webm.jpg"),
                director: "George A. Romero"
            ),
            compactStreams([
                ("1080p Full HD · Complete Film", "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/24/Night_of_the_Living_Dead_%281968%29.webm/Night_of_the_Living_Dead_%281968%29.webm.1080p.vp9.webm", "Full 96-minute restored 1080p feature film"),
                ("360p Native AVPlayer · QuickTime", "https://upload.wikimedia.org/wikipedia/commons/transcoded/2/24/Night_of_the_Living_Dead_%281968%29.webm/Night_of_the_Living_Dead_%281968%29.webm.360p.mpeg4.mov", "Hardware AVPlayer stream with PiP & AirPlay")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-gullivers-travels",
                externalIDs: [.openCinema: "wmfile:File:Gulliver's Travels (1939).webm"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Gulliver's Travels (Full Animated Movie)",
                originalTitle: "Gulliver's Travels",
                synopsis: "Lemuel Gulliver washes ashore on Lilliput and attempts to prevent war between that tiny kingdom and its rival Blefuscu in Fleischer Studios' Technicolor animated feature film.",
                releaseYear: 1939,
                countryOfOrigin: "US",
                originalLanguage: "en",
                ageRating: "6+",
                genres: ["Animation", "Adventure", "Family"],
                durationMinutes: 76,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.1),
                popularityScore: 945,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Gulliver%27s_Travels_%281939%29.webm/960px-Gulliver%27s_Travels_%281939%29.webm.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Gulliver%27s_Travels_%281939%29.webm/960px-Gulliver%27s_Travels_%281939%29.webm.jpg"),
                director: "Dave Fleischer"
            ),
            compactStreams([
                ("1080p Full HD · Animated Feature", "https://upload.wikimedia.org/wikipedia/commons/b/bb/Gulliver%27s_Travels_%281939%29.webm", "Complete 76-minute Technicolor animated feature")
            ])
        ),
        (
            makeSupermanAnimatedSeries(),
            compactStreams([
                ("1080p Full HD · Episode 1", "https://upload.wikimedia.org/wikipedia/commons/transcoded/4/49/The_Mechanical_Monsters.webm/The_Mechanical_Monsters.webm.1080p.vp9.webm", "Fleischer Studios Season 1 Episodes 1–4 with Skip Intro")
            ])
        ),
        (
            MediaItem(
                id: "opencinema:movie:open-cosmos-laundromat",
                externalIDs: [.openCinema: "wmfile:File:Cosmos Laundromat - First Cycle - Official Blender Foundation release.webm"],
                primarySource: .openCinema,
                projectType: .cartoonMovie,
                localizedTitle: "Cosmos Laundromat (2K · 28 Subtitles)",
                originalTitle: "Cosmos Laundromat",
                synopsis: "On a desolate island, a suicidal sheep named Franck meets a quirky salesman who offers him the gift of a lifetime: endless worlds inside a cosmic laundromat.",
                releaseYear: 2015,
                countryOfOrigin: "NL",
                originalLanguage: "en",
                ageRating: "12+",
                genres: ["Animation", "Sci-Fi", "Comedy"],
                durationMinutes: 12,
                releaseStatus: .finished,
                ratings: MultiSourceRatings(tmdbScore: 7.7),
                popularityScore: 910,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm/960px-Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm/960px-Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm.jpg"),
                director: "Mathieu Auvray (Blender Institute)"
            ),
            compactStreams([
                ("2K Cinema · 28 Subtitle Languages", "https://upload.wikimedia.org/wikipedia/commons/3/36/Cosmos_Laundromat_-_First_Cycle_-_Official_Blender_Foundation_release.webm", "2048×858 2K master with Russian, English, Japanese & 25 more subtitles")
            ])
        )
    ]

    public static var items: [MediaItem] {
        films.map(\.item)
    }

    public static func streams(forItemID id: String) -> [OpenCinemaStream] {
        if let direct = films.first(where: { $0.item.id == id }) {
            return direct.streams
        }
        let movieID = "opencinema:movie:\(id)"
        if let matchMovie = films.first(where: { $0.item.id == movieID }) {
            return matchMovie.streams
        }
        let tvID = "opencinema:tv:\(id)"
        return films.first(where: { $0.item.id == tvID })?.streams ?? []
    }

    private static func makeSupermanAnimatedSeries() -> MediaItem {
        let episodes: [MediaEpisode] = [
            MediaEpisode(
                id: "opencinema:tv:open-superman-series:s1:e1",
                seasonNumber: 1,
                episodeNumber: 1,
                title: "The Mechanical Monsters",
                synopsis: "A mysterious inventor commands an army of flying jewel-robbing robots across Metropolis while Lois Lane gets trapped inside one.",
                durationMinutes: 10,
                directStreamURL: URL(string: "wmfile:File:The Mechanical Monsters.webm"),
                introStartSeconds: 4,
                introEndSeconds: 44
            ),
            MediaEpisode(
                id: "opencinema:tv:open-superman-series:s1:e2",
                seasonNumber: 1,
                episodeNumber: 2,
                title: "Billion Dollar Limited",
                synopsis: "Saboteurs hijack a high-speed armoured train carrying one billion dollars in gold bullion to the U.S. Mint.",
                durationMinutes: 9,
                directStreamURL: URL(string: "wmfile:File:Billion Dollar Limited.webm"),
                introStartSeconds: 4,
                introEndSeconds: 42
            ),
            MediaEpisode(
                id: "opencinema:tv:open-superman-series:s1:e3",
                seasonNumber: 1,
                episodeNumber: 3,
                title: "The Arctic Giant",
                synopsis: "A prehistoric Tyrannosaurus thawed from Siberian ice breaks loose in Metropolis, toppling bridges and skyscrapers.",
                durationMinutes: 9,
                directStreamURL: URL(string: "wmfile:File:The Arctic Giant (1942).webm"),
                introStartSeconds: 4,
                introEndSeconds: 42
            ),
            MediaEpisode(
                id: "opencinema:tv:open-superman-series:s1:e4",
                seasonNumber: 1,
                episodeNumber: 4,
                title: "Volcano",
                synopsis: "Clark Kent and Lois Lane travel to cover a rumbling Caribbean volcano just as Mount Monokoa erupts violently.",
                durationMinutes: 8,
                directStreamURL: URL(string: "wmfile:File:Volcano (1942).webm"),
                introStartSeconds: 4,
                introEndSeconds: 42
            )
        ]

        let season1 = MediaSeason(
            id: "opencinema:tv:open-superman-series:s1",
            seasonNumber: 1,
            title: "Season 1",
            overview: "Restored Technicolor episodes produced by Fleischer Studios.",
            episodeCount: episodes.count,
            releaseYear: 1941,
            episodes: episodes
        )

        return MediaItem(
            id: "opencinema:tv:open-superman-series",
            externalIDs: [.openCinema: "wmfile:File:The Mechanical Monsters.webm"],
            primarySource: .openCinema,
            projectType: .cartoonSeries,
            localizedTitle: "Superman: The Fleischer Animated Series",
            originalTitle: "Superman (1941 Animated Series)",
            synopsis: "Landmark Technicolor animated series by Dave and Max Fleischer following Clark Kent and Lois Lane across thrilling sci-fi adventures in Metropolis. Full playable HD episodes with Skip Intro and Next Episode.",
            releaseYear: 1941,
            countryOfOrigin: "US",
            originalLanguage: "en",
            ageRating: "6+",
            genres: ["Animation", "Action", "Sci-Fi"],
            durationMinutes: 9,
            totalSeasons: 1,
            totalEpisodes: episodes.count,
            releaseStatus: .finished,
            ratings: MultiSourceRatings(tmdbScore: 8.1),
            popularityScore: 960,
            posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/The_Mechanical_Monsters.webm/960px-The_Mechanical_Monsters.webm.jpg"),
            backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/The_Mechanical_Monsters.webm/960px-The_Mechanical_Monsters.webm.jpg"),
            director: "Dave Fleischer",
            seasons: [season1]
        )
    }

    private static func compactStreams(_ specs: [(label: String, urlString: String, note: String)]) -> [OpenCinemaStream] {
        specs.compactMap { spec in
            guard let url = URL(string: spec.urlString) else { return nil }
            return OpenCinemaStream(label: spec.label, url: url, note: spec.note)
        }
    }
}
