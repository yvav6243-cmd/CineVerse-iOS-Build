import Foundation
import Testing
@testable import CineVerse

private final class MapperBundleAnchor {}

@Suite("Category 7: API Mappers, DTO Decoding, Merger & References")
struct MapperDecodingTests {
    @Test func decodesAndMapsTMDBMovieFixture() throws {
        let bundle = Bundle(for: MapperBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "tmdb_movie_details", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(TMDBMovieDetailsDTO.self, from: data)
        let item = TMDBMapper.mapMovieDetails(dto, watchRegion: "US")

        #expect(item.id == "tmdb:movie:157336")
        #expect(item.localizedTitle == "Interstellar")
        #expect(item.director == "Christopher Nolan")
        #expect(item.ageRating == "PG-13")
        #expect(item.durationMinutes == 169)
        #expect(item.trailerURL?.absoluteString == "https://www.youtube.com/watch?v=zSWdZVtXT7E")
        #expect(item.officialPlatformLinks.first?.siteName == "Paramount Plus")
    }

    @Test func decodesAndMapsAniListFixture() throws {
        let bundle = Bundle(for: MapperBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "anilist_media", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(AniListGraphQLResponse<AniListMediaDataDTO>.self, from: data)
        let media = try #require(response.data?.media)
        let item = AniListMapper.mapMedia(media)

        #expect(item.id == "anilist:anime:154587")
        #expect(item.projectType == .anime)
        #expect(item.originalTitle == "葬送のフリーレン")
        #expect(item.ratings.aniListScore == 9.1)
        #expect(item.director == "Keiichirou Saitou")
        #expect(item.totalEpisodes == 28)
        #expect(item.officialPlatformLinks.first?.siteName == "Crunchyroll")
    }

    @Test func decodesAndMapsTVMazeFixture() throws {
        let bundle = Bundle(for: MapperBundleAnchor.self)
        let url = try #require(bundle.url(forResource: "tvmaze_show", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(TVMazeShowDTO.self, from: data)
        let item = TVMazeMapper.mapShowWithRating(dto, averageRating: 9.2)

        #expect(item.id == "tvmaze:tv:169")
        #expect(item.localizedTitle == "Breaking Bad")
        #expect(item.synopsis == "Breaking Bad follows Walter White.")
        #expect(item.ratings.tvMazeScore == 9.2)
        #expect(item.seasons.first?.episodes.first?.title == "Pilot")
    }

    @Test func tvMazeMapperClassifiesKoreanDramaAndWesternAnimationCorrectly() throws {
        let koreanJSON = """
        {"id": 501, "name": "Crash Landing", "type": "Scripted", "language": "Korean", "genres": ["Drama", "Romance"], "status": "Ended"}
        """
        let koreanDTO = try JSONDecoder().decode(TVMazeShowDTO.self, from: Data(koreanJSON.utf8))
        let kdrama = TVMazeMapper.mapShow(koreanDTO)
        #expect(kdrama.projectType == .drama)
        #expect(kdrama.originalLanguage == "ko")

        let westernToonJSON = """
        {"id": 502, "name": "Space Toon", "type": "Animation", "language": "English", "genres": ["Comedy"], "status": "Running"}
        """
        let toonDTO = try JSONDecoder().decode(TVMazeShowDTO.self, from: Data(westernToonJSON.utf8))
        let cartoon = TVMazeMapper.mapShow(toonDTO)
        #expect(cartoon.projectType == .cartoonSeries)
        #expect(cartoon.releaseStatus == .releasing)
    }

    @Test func tvMazeMapperUpgradesInsecureHTTPImageURLsToHTTPS() throws {
        let json = """
        {"id": 600, "name": "Retro Show", "image": {"medium": "http://static.tvmaze.com/uploads/images/medium.jpg", "original": "http://static.tvmaze.com/uploads/images/orig.jpg"}}
        """
        let dto = try JSONDecoder().decode(TVMazeShowDTO.self, from: Data(json.utf8))
        let item = TVMazeMapper.mapShow(dto)
        #expect(item.posterURL?.scheme == "https")
    }

    @Test func decodesITunesRSSSingleEntryAndArrayEntryFormats() throws {
        let singleEntryJSON = """
        {
          "feed": {
            "entry": {
              "im:name": {"label": "Dune: Part Two"},
              "id": {"label": "https://itunes.apple.com/us/movie/id1", "attributes": {"im:id": "17291234"}},
              "im:image": [{"label": "https://is1-ssl.mzstatic.com/image/thumb/Video/v4/100x100bb.jpg"}],
              "category": {"attributes": {"im:id": "4413", "label": "Sci-Fi & Fantasy"}},
              "im:releaseDate": {"label": "2024-03-01T00:00:00-07:00"},
              "link": {
                "attributes": {"rel": "enclosure", "type": "video/x-m4v", "href": "https://video-ssl.itunes.apple.com/preview.m4v"}
              }
            }
          }
        }
        """
        let root = try JSONDecoder().decode(ITunesRSSRootDTO.self, from: Data(singleEntryJSON.utf8))
        let entry = try #require(root.feed?.entry?.first)
        let mapped = try #require(ITunesMapper.mapRSSEntry(entry, rankIndex: 0, forcedGenreID: nil, forcedProjectType: nil))

        #expect(mapped.id == "opencinema:movie:itunes-17291234")
        #expect(mapped.localizedTitle == "Dune: Part Two")
        #expect(mapped.posterURL?.absoluteString.hasSuffix("/600x900bb.jpg") == true)
        #expect(mapped.backdropURL?.absoluteString.hasSuffix("/1000x1500bb.jpg") == true)
        #expect(mapped.externalIDs[.openCinema] == "https://video-ssl.itunes.apple.com/preview.m4v")
    }

    @Test func mapsITunesSearchTrackAndClassifiesAnimatedAndDocumentaryGenres() throws {
        let trackJSON = """
        {
          "wrapperType": "track",
          "kind": "feature-movie",
          "trackId": 987654,
          "trackName": "Animated Wonder",
          "artistName": "Jane Director",
          "previewUrl": "https://video-ssl.itunes.apple.com/wonder.m4v",
          "artworkUrl100": "https://is1-ssl.mzstatic.com/image/thumb/100x100bb.jpg",
          "releaseDate": "2023-11-15T08:00:00Z",
          "trackTimeMillis": 5700000,
          "primaryGenreName": "Kids & Family",
          "longDescription": "Family adventure."
        }
        """
        let dto = try JSONDecoder().decode(ITunesTrackDTO.self, from: Data(trackJSON.utf8))
        let item = try #require(ITunesMapper.mapTrack(dto, rankIndex: 0))
        #expect(item.projectType == .cartoonMovie)
        #expect(item.durationMinutes == 95)
        #expect(item.releaseYear == 2023)
    }

    @Test func mediaMergerCombinesCrossProviderScoresForMatchingTitleAndYear() {
        let tvMazeVersion = MediaItem(
            id: "tvmaze:tv:10", primarySource: .tvMaze, projectType: .tvSeries,
            localizedTitle: "Severance", originalTitle: "Severance", synopsis: "Short",
            releaseYear: 2022, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama"], durationMinutes: 50, ratings: MultiSourceRatings(tvMazeScore: 8.6)
        )
        let tmdbVersion = MediaItem(
            id: "tmdb:tv:95396", primarySource: .tmdb, projectType: .tvSeries,
            localizedTitle: "Severance", originalTitle: "Severance", synopsis: "Full TMDB overview",
            releaseYear: 2022, countryOfOrigin: "US", originalLanguage: "en",
            genres: ["Drama", "Sci-Fi"], durationMinutes: 50, ratings: MultiSourceRatings(tmdbScore: 8.4)
        )

        let merged = MediaMerger.merge([tvMazeVersion, tmdbVersion])
        #expect(merged.count == 1)
        #expect(merged.first?.primarySource == .tmdb)
        #expect(merged.first?.ratings.tmdbScore == 8.4)
        #expect(merged.first?.ratings.tvMazeScore == 8.6)
    }

    @Test func mediaMergerKeepsMoviesAndEpisodicShowsWithSameTitleSeparate() {
        let film = MediaItem(
            id: "tmdb:movie:1", primarySource: .tmdb, projectType: .movie,
            localizedTitle: "Fargo", originalTitle: "Fargo", synopsis: "",
            releaseYear: 2014, countryOfOrigin: "US", originalLanguage: "en",
            genres: [], durationMinutes: 98, ratings: MultiSourceRatings(tmdbScore: 8.1)
        )
        let series = MediaItem(
            id: "tmdb:tv:2", primarySource: .tmdb, projectType: .tvSeries,
            localizedTitle: "Fargo", originalTitle: "Fargo", synopsis: "",
            releaseYear: 2014, countryOfOrigin: "US", originalLanguage: "en",
            genres: [], durationMinutes: 52, ratings: MultiSourceRatings(tmdbScore: 8.9)
        )
        #expect(MediaMerger.merge([film, series]).count == 2)
    }

    @Test func mediaReferenceRoundTripsAllProvidersAndBuildsShareURLs() {
        let tmdbRef = MediaReference(id: "tmdb:movie:157336")
        #expect(tmdbRef?.provider == .tmdb)
        #expect(tmdbRef?.kind == .movie)
        #expect(tmdbRef?.shareURL?.absoluteString == "https://www.themoviedb.org/movie/157336")

        let aniRef = MediaReference(id: "anilist:anime:154587")
        #expect(aniRef?.shareURL?.absoluteString == "https://anilist.co/anime/154587")

        let itunesRef = MediaReference(id: "opencinema:movie:itunes-554433")
        #expect(itunesRef?.shareURL?.absoluteString == "https://itunes.apple.com/us/movie/id554433")

        let openRef = MediaReference(id: "opencinema:movie:open-sintel")
        #expect(openRef?.shareURL == nil)
    }

    @Test func rejectsMalformedMediaReferenceStrings() {
        #expect(MediaReference(id: "") == nil)
        #expect(MediaReference(id: "unknown:movie:123") == nil)
        #expect(MediaReference(id: "tmdb:podcast:123") == nil)
        #expect(MediaReference(id: "tmdb:movie:") == nil)
    }
}
