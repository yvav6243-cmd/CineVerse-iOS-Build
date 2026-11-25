import Foundation

public enum AniListQueries {
    public static let pageMedia = """
    query PageMedia(
      $page: Int,
      $perPage: Int,
      $search: String,
      $sort: [MediaSort],
      $genres: [String],
      $seasonYear: Int,
      $startDateGreater: FuzzyDateInt,
      $startDateLesser: FuzzyDateInt,
      $countryOfOrigin: CountryCode,
      $formats: [MediaFormat],
      $status: MediaStatus,
      $averageScoreGreater: Int,
      $averageScoreLesser: Int,
      $durationLesser: Int
    ) {
      Page(page: $page, perPage: $perPage) {
        pageInfo {
          hasNextPage
        }
        media(
          type: ANIME,
          search: $search,
          sort: $sort,
          genre_in: $genres,
          seasonYear: $seasonYear,
          startDate_greater: $startDateGreater,
          startDate_lesser: $startDateLesser,
          countryOfOrigin: $countryOfOrigin,
          format_in: $formats,
          status: $status,
          averageScore_greater: $averageScoreGreater,
          averageScore_lesser: $averageScoreLesser,
          duration_lesser: $durationLesser,
          isAdult: false
        ) {
          id
          idMal
          title {
            romaji
            english
            native
          }
          synonyms
          description(asHtml: false)
          format
          status
          episodes
          duration
          seasonYear
          startDate {
            year
            month
            day
          }
          countryOfOrigin
          genres
          averageScore
          popularity
          coverImage {
            extraLarge
            color
          }
          bannerImage
          studios(isMain: true) {
            nodes {
              name
            }
          }
          staff(perPage: 4) {
            edges {
              role
              node {
                id
                name { full }
              }
            }
          }
          characters(perPage: 6, sort: [ROLE]) {
            edges {
              role
              node { name { full } }
              voiceActors(language: JAPANESE) { name { full } }
            }
          }
          nextAiringEpisode {
            airingAt
            episode
          }
        }
      }
    }
    """

    public static let mediaDetails = """
    query MediaDetails($id: Int!) {
      Media(id: $id, type: ANIME) {
        id
        idMal
        title {
          romaji
          english
          native
        }
        synonyms
        description(asHtml: false)
        format
        status
        episodes
        duration
        seasonYear
        startDate {
          year
          month
          day
        }
        countryOfOrigin
        genres
        averageScore
        popularity
        coverImage {
          extraLarge
          color
        }
        bannerImage
        isAdult
        trailer {
          id
          site
          thumbnail
        }
        nextAiringEpisode {
          airingAt
          episode
        }
        studios(isMain: true) {
          nodes {
            name
          }
        }
        staff(perPage: 8) {
          edges {
            role
            node {
              id
              name {
                full
              }
              image {
                medium
              }
            }
          }
        }
        characters(perPage: 16, sort: [ROLE]) {
          edges {
            role
            node {
              name {
                full
              }
              image {
                medium
              }
            }
            voiceActors(language: JAPANESE) {
              name {
                full
              }
            }
          }
        }
        recommendations(perPage: 12) {
          nodes {
            mediaRecommendation {
              id
              idMal
              title {
                romaji
                english
                native
              }
              description(asHtml: false)
              format
              status
              episodes
              duration
              seasonYear
              startDate {
                year
                month
                day
              }
              countryOfOrigin
              genres
              averageScore
              popularity
              coverImage {
                extraLarge
                color
              }
              bannerImage
              nextAiringEpisode {
                airingAt
                episode
              }
            }
          }
        }
        streamingEpisodes {
          title
          thumbnail
          url
          site
        }
        externalLinks {
          site
          url
          type
          language
        }
      }
    }
    """

    public static let airingSchedule = """
    query AiringSchedule($page: Int, $airingAtGreater: Int, $airingAtLesser: Int) {
      Page(page: $page, perPage: 50) {
        airingSchedules(
          airingAt_greater: $airingAtGreater,
          airingAt_lesser: $airingAtLesser,
          sort: TIME
        ) {
          airingAt
          episode
          media {
            id
            idMal
            title {
              romaji
              english
              native
            }
            format
            status
            episodes
            duration
            seasonYear
            countryOfOrigin
            genres
            averageScore
            popularity
            coverImage {
              extraLarge
              color
            }
            bannerImage
            isAdult
          }
        }
      }
    }
    """

    public static let genres = """
    query GenreCollection {
      GenreCollection
    }
    """

    public static let searchEntities = """
    query SearchEntities($q: String!) {
      studios: Page(page: 1, perPage: 2) {
        studios(search: $q, sort: SEARCH_MATCH) {
          name
          media(sort: POPULARITY_DESC, perPage: 8, isMain: true) {
            nodes {
              id idMal format status episodes duration seasonYear countryOfOrigin genres averageScore popularity bannerImage isAdult
              title { romaji english native }
              coverImage { extraLarge color }
            }
          }
        }
      }
      characters: Page(page: 1, perPage: 3) {
        characters(search: $q, sort: SEARCH_MATCH) {
          name { full }
          media(type: ANIME, sort: POPULARITY_DESC, perPage: 6) {
            nodes {
              id idMal format status episodes duration seasonYear countryOfOrigin genres averageScore popularity bannerImage isAdult
              title { romaji english native }
              coverImage { extraLarge color }
            }
          }
        }
      }
      staff: Page(page: 1, perPage: 2) {
        staff(search: $q, sort: SEARCH_MATCH) {
          name { full }
          staffMedia(type: ANIME, sort: POPULARITY_DESC, perPage: 6) {
            nodes {
              id idMal format status episodes duration seasonYear countryOfOrigin genres averageScore popularity bannerImage isAdult
              title { romaji english native }
              coverImage { extraLarge color }
            }
          }
        }
      }
    }
    """
}
