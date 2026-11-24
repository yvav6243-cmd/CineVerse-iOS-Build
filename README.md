# CineVerse — Personal Entertainment Platform for iOS

CineVerse is a native iOS application built with **Swift**, **SwiftUI**, **AVFoundation**, **SwiftData**, **Swift Charts**, **WidgetKit**, and **ActivityKit**. It combines a multi-provider entertainment catalog (movies, anime, TV series, cartoons, dramas, documentaries, and specials), a local personal watch tracker and library, and a custom AVFoundation video player with pre-watch audio/voiceover, quality, and subtitle configuration.

## Requirements

- **Xcode 26+** (iOS 26 SDK, for Liquid Glass `.glassEffect` support)
- **iOS 18.0+** deployment target (iPhone)
- **XcodeGen** (`brew install xcodegen`)
- Free **TMDB API Key** (v3) or Read Access Token (v4) for movie/TV discovery and metadata (optional for AniList anime and TVmaze shows, which work without keys)

## Setup & Build

1. Install XcodeGen if not already installed:
   ```bash
   brew install xcodegen
   ```
2. Configure your TMDB API credential (or enter it in-app under **Profile → API Keys**, where it is stored in the iOS Keychain):
   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   # Edit Config/Secrets.xcconfig with your TMDB_API_KEY and DEVELOPMENT_TEAM
   ```
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
4. Open `CineVerse.xcodeproj` in Xcode, verify signing team on `CineVerse` and `CineVerseWidgets`, and build/run on Simulator or iPhone (`⌘R`) or run unit tests (`⌘U`).

## Architecture

- **MVVM + Repository Pattern + Dependency Injection** (`AppContainer` & `AppCoordinator`)
- **Networking (`Core/Networking`)**: `URLSession`-based `HTTPClient` with HTTPS enforcement, per-host `RateLimiter`, exponential retry on 429/5xx, `NWPathMonitor` offline detection, and SHA-256 keyed `ResponseDiskCache`.
- **Persistence (`Core/Database`)**: On-device SwiftData models (`LibraryEntryRecord`, `PlaybackProgressRecord`, `WatchHistoryRecord`, `CustomCollectionRecord`, `CollectionItemRecord`, `SearchHistoryRecord`, `UserVideoSourceRecord`, `AppPreferencesRecord`), plus JSON backup export/import.
- **Video Source Manager (`Data/Providers`)**: Extensible `VideoSourceProvider` architecture supporting on-device imported files, validated HTTPS `.m3u8`/`.mp4`/`.m4v`/`.mov` direct links, verified public-domain/CC releases on Internet Archive, and official external service links. `MediaSourceInspector` inspects HLS master manifests and `AVURLAsset` tracks so only actually available qualities, audio tracks/voiceovers, and subtitles are presented.
- **Custom AVFoundation Player (`Features/Player`)**: Custom SwiftUI overlay over `AVPlayerLayer` (no system `AVPlayerViewController` UI), supporting 10s skip gestures, custom scrubber with buffer bar, live audio track switching, quality caps, external SRT/WebVTT subtitle parser & style customization, playback speed (`0.5x`–`2.0x`), orientation lock/rotation, screen lock, Picture in Picture, AirPlay, Control Center (`MPNowPlayingInfoCenter`), and Dynamic Island (`ActivityKit`).

## Data Sources & Attribution

- **TMDB**: This product uses the TMDB API but is not endorsed or certified by TMDB.
- **AniList**: Public GraphQL API for anime metadata and airing schedules.
- **TVmaze**: TV show metadata and broadcast schedules licensed under CC BY-SA.
- **Jikan**: Unofficial MyAnimeList REST API used for supplemental anime episode titles and air dates.
- **Internet Archive**: Public domain and Creative Commons media lookup (`archive.org`).

## Playback & Legal Notice

CineVerse does not include DRM circumvention, scraping, or unauthorized third-party streaming bridges. Commercial titles without user-provided streams or public-domain availability display official streaming service links that open safely in their official destinations.
