import Foundation
import Testing
@testable import CineVerse

private final class MapperBundleAnchor {}

@Suite("API Mapper Decoding")
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
}
