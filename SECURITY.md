# CineVerse Security & Privacy Review

This document records the security controls implemented across the CineVerse iOS codebase.

## 1. Secrets & API Credentials
- **No hardcoded credentials**: Source files contain zero embedded API keys (`TMDBAPIKey` in `Info.plist` expands `$(TMDB_API_KEY)` from `Config/Base.xcconfig`, which optionally includes the gitignored `Config/Secrets.xcconfig`).
- **Keychain storage**: Runtime credentials entered in **Profile → API Keys** (`APIKeysView.swift`) are stored via `KeychainStore` (`kSecAttrAccessibleAfterFirstUnlock`) and prioritized by `SecretsProvider.tmdbCredential()`.

## 2. Permissions & Entitlements
- **Minimal permissions**: No camera, microphone, location, contacts, or photo library usage descriptions are requested. Avatar selection uses Apple's out-of-process `PhotosPicker`.
- **On-demand notifications**: Push/local notification permission (`EpisodeAlertScheduler.requestAuthorization()`) is requested only when the user explicitly turns on Episode Alerts in Settings or toggles a premiere reminder bell.
- **App Groups**: Shared container (`$(CV_APP_GROUP)`) is used solely for passing `WidgetSnapshot` JSON and downsampled poster thumbnails from the main app to `CineVerseWidgets`.

## 3. Transport Security & External Source Validation
- **App Transport Security (ATS)**: Default strict ATS is enforced (`Info.plist` defines no `NSAllowsArbitraryLoads` or domain exceptions). `Endpoint.makeRequest()` rejects any non-HTTPS endpoint URL.
- **Custom stream URL validation (`SourceURLValidator`)**:
  - Rejects non-HTTPS schemes (`http://`, `file://`, custom schemes).
  - Enforces a 2048-character URL cap.
  - Rejects embedded credentials (`user:pass@host`).
  - Blocks `localhost`, `.local`, loopback (`127.0.0.1`, `::1`), and private/link-local IPv4 ranges (`10.x`, `172.16–31.x`, `192.168.x`, `169.254.x`).
  - Blocks executable and archive extensions (`.exe`, `.ipa`, `.apk`, `.dmg`, `.pkg`, `.app`, `.sh`, `.bat`, `.js`, `.zip`, `.rar`, `.7z`, `.msi`, `.deb`, `.cmd`, `.ps1`, `.scr`, `.tar`, `.gz`).
  - Performs a `HEAD` (or 1 KB `Range` `GET` fallback) reachability check validating `Content-Type` (`video/*` or HLS `.m3u8` MIME types) before saving a direct link.
- **Bounded downloads**: HLS manifest inspection (`MediaSourceInspector`) is capped at 1 MB; external subtitle downloads (`SubtitleEngine`) are capped at 5 MB.
- **No executable downloads**: Only media containers/manifests (`.m3u8`, `.mp4`, `.m4v`, `.mov`), images, JSON/GraphQL metadata, and text subtitles (`.srt`, `.vtt`) are fetched.

## 4. On-Device Data Protection & Privacy
- **Local-only user data**: Watch history, playback progress, library entries, personal scores, notes, search history, and custom collections reside locally on-device in SwiftData (`PersistenceController`).
- **Zero tracking / telemetry**: `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false` and zero collected data types, with required-reason API declarations (`CA92.1` UserDefaults, `C617.1` FileTimestamp, `E174.1` DiskSpace).
- **Privacy-preserving recommendations (`RecommendationEngine`)**: Taste scoring runs entirely on-device; only public genre names (never user history, ratings, or tracked IDs) are used in public discovery queries.
- **Protected local media storage (`LocalVideoStore`)**: User-imported video and subtitle files are copied into `Application Support/{Videos,Subtitles}`, marked `isExcludedFromBackup = true`, and protected with `FileProtectionType.completeUntilFirstUserAuthentication`.

## 5. External Links & Content Licensing Boundaries
- **Confirmed external navigation (`ExternalLinkGuard`)**: Official streaming links and trailers are verified HTTPS URLs and present an explicit confirmation dialog displaying the destination host before opening outside the app.
- **No DRM circumvention**: CineVerse never decrypts, scrapes, or bypasses DRM or authentication on third-party platforms; non-playable commercial services expose direct links to the official platforms instead.
