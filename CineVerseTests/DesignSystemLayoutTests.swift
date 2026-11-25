import Foundation
import SwiftUI
import Testing
@testable import CineVerse

@Suite("Category 1: Design System, Colors & Responsive Layout")
struct DesignSystemLayoutTests {
    @Test func parsesSixDigitHexColorAccurately() {
        let rgba = Color.parseHexRGBA("#6E5BFF")
        #expect(abs(rgba.r - 110.0 / 255.0) < 0.001)
        #expect(abs(rgba.g - 91.0 / 255.0) < 0.001)
        #expect(abs(rgba.b - 1.0) < 0.001)
        #expect(rgba.a == 1.0)
    }

    @Test func parsesThreeDigitShorthandAndEightDigitARGBHex() {
        let short = Color.parseHexRGBA("#F0A")
        #expect(abs(short.r - 1.0) < 0.001)
        #expect(abs(short.g - 0.0) < 0.001)
        #expect(abs(short.b - 170.0 / 255.0) < 0.001)

        let argb = Color.parseHexRGBA("#80FF8000")
        #expect(abs(argb.a - 128.0 / 255.0) < 0.005)
        #expect(abs(argb.r - 1.0) < 0.001)
        #expect(abs(argb.g - 128.0 / 255.0) < 0.005)
        #expect(abs(argb.b - 0.0) < 0.001)
    }

    @Test func invalidHexStringsFallbackGracefullyToBrandIris() {
        let empty = Color.parseHexRGBA("")
        let malformed = Color.parseHexRGBA("ZZZZZZ")
        let oddLength = Color.parseHexRGBA("#12345")
        #expect(abs(empty.r - 110.0 / 255.0) < 0.001)
        #expect(abs(malformed.b - 1.0) < 0.001)
        #expect(oddLength.a == 1.0)
    }

    @Test func categoryAccentColorsAvoidIllegiblePureWhiteOrLemonYellow() {
        for category in MediaProjectType.allCases {
            let hex = CategoryGridView.accentHex(for: category)
            let lum = Color.relativeLuminance(hex: hex)
            // Pure white has luminance 1.0 and unreadable lemon yellow > 0.80 on white glass;
            // all category accents must stay below 0.72 so icons remain visible in Light Mode.
            #expect(lum > 0.05 && lum < 0.72, "Category \(category) accent \(hex) has extreme luminance \(lum)")
        }
    }

    @Test func gridMetricsYieldTwoColumnsOnCompactIPhoneWidths() {
        for width: CGFloat in [320, 360, 375, 390, 393, 430] {
            let cols = CVGridLayoutMetrics.columnCount(for: width)
            let cardW = CVGridLayoutMetrics.cardWidth(for: width)
            #expect(cols == 2)
            #expect(cardW >= 130 && cardW <= 210)
            let totalNeeded = cardW * CGFloat(cols) + CVSpacing.sm * CGFloat(cols - 1) + CVSpacing.md * 2
            if width >= 360 {
                #expect(totalNeeded <= width + 1)
            }
        }
    }

    @Test func gridMetricsScaleUpCleanlyInLandscapeWidths() {
        let colsLandscape = CVGridLayoutMetrics.columnCount(for: 844)
        let cardLandscape = CVGridLayoutMetrics.cardWidth(for: 844)
        #expect(colsLandscape >= 4 && colsLandscape <= 6)
        #expect(cardLandscape >= 145 && cardLandscape <= 210)
        #expect(CVGridLayoutMetrics.columns(for: 844).count == colsLandscape)
    }

    @Test func gridMetricsHandleZeroNegativeAndInfiniteWidthsSafely() {
        #expect(CVGridLayoutMetrics.columnCount(for: 0) == 2)
        #expect(CVGridLayoutMetrics.columnCount(for: -50) == 2)
        #expect(CVGridLayoutMetrics.columnCount(for: .infinity) == 2)
        #expect(CVGridLayoutMetrics.cardWidth(for: 0) == 160)
        #expect(CVGridLayoutMetrics.cardWidth(for: .nan) == 160)
    }

    @Test func allMediaProjectTypesUseValidSFSymbolsWithoutEmojis() {
        for type in MediaProjectType.allCases {
            #expect(!type.symbolName.isEmpty)
            #expect(!type.displayName.isEmpty)
            #expect(!type.pluralTitle.isEmpty)
            #expect(type.symbolName.unicodeScalars.allSatisfy { $0.isASCII })
        }
    }

    @Test func allWatchTrackingStatusesHaveDistinctValidHexAccentsAndSymbols() {
        for status in WatchTrackingStatus.allCases {
            #expect(status.accentHex.hasPrefix("#"))
            #expect(status.accentHex.count == 7)
            #expect(!status.symbolName.isEmpty)
            #expect(status.symbolName.unicodeScalars.allSatisfy { $0.isASCII })
        }
    }

    @Test func timeIntervalFormattingHandlesSecondsHoursAndInvalidValues() {
        #expect(TimeInterval(-5).formattedPlaybackTime == "00:00")
        #expect(TimeInterval.nan.formattedPlaybackTime == "00:00")
        #expect(TimeInterval.infinity.formattedPlaybackTime == "00:00")
        #expect(TimeInterval(65).formattedPlaybackTime == "01:05")
        #expect(TimeInterval(3661).formattedPlaybackTime == "1:01:01")
        #expect(TimeInterval(5400).formattedRemainingBrief == "1h 30m")
        #expect(TimeInterval(3600).formattedRemainingBrief == "1h")
        #expect(TimeInterval(25).formattedRemainingBrief == "1m")
    }

    @Test func stringHTMLStrippingDecodesEntitiesAndPreservesParagraphs() {
        let raw = "<p>Hello &amp; welcome<br/>to <b>CineVerse</b> &mdash; &#39;2026&#39;!</p><script>ignored</script>"
        let cleaned = raw.strippedHTML
        #expect(cleaned.contains("Hello & welcome"))
        #expect(cleaned.contains("to CineVerse — '2026'!"))
        #expect(!cleaned.contains("<p>"))
        #expect(!cleaned.contains("<b>"))
    }

    @MainActor
    @Test func deepLinkRouterNavigatesToTabsCalendarAndMediaDetails() throws {
        let coordinator = AppCoordinator()
        DeepLinkRouter.handle(url: try #require(URL(string: "cineverse://tab/tracker")), coordinator: coordinator)
        #expect(coordinator.selectedTab == .tracker)

        DeepLinkRouter.handle(url: try #require(URL(string: "cineverse://calendar")), coordinator: coordinator)
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.homePath.count == 1)

        DeepLinkRouter.handle(url: try #require(URL(string: "cineverse://media/tmdb:movie:157336")), coordinator: coordinator)
        #expect(coordinator.homePath.count == 2)
    }

    @MainActor
    @Test func deepLinkRouterIgnoresForeignSchemesAndMalformedIDs() throws {
        let coordinator = AppCoordinator()
        DeepLinkRouter.handle(url: try #require(URL(string: "https://example.com/tab/explore")), coordinator: coordinator)
        #expect(coordinator.selectedTab == .home)
        DeepLinkRouter.handle(url: try #require(URL(string: "cineverse://media/not-a-valid-ref")), coordinator: coordinator)
        #expect(coordinator.homePath.isEmpty)
    }
}
