import Foundation
import SwiftUI

// MARK: - String HTML & Formatting Extensions

public extension String {
    /// Strips HTML tags returned by AniList and TVmaze descriptions while preserving line breaks.
    var strippedHTML: String {
        guard !isEmpty else { return "" }
        var working = self
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)

        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: working.utf16.count)
            working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: "")
        }

        let entities: [String: String] = [
            "&quot;": "\"",
            "&amp;": "&",
            "&apos;": "'",
            "&#039;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–"
        ]
        for (entity, replacement) in entities {
            working = working.replacingOccurrences(of: entity, with: replacement)
        }
        return working
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedForComparison: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

// MARK: - TimeInterval Playback Formatting

public extension TimeInterval {
    var formattedPlaybackTime: String {
        guard isFinite && !isNaN && self >= 0 else { return "00:00" }
        let totalSeconds = Int(self.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedRemainingBrief: String {
        guard isFinite && !isNaN && self > 0 else { return "0m" }
        let totalMinutes = Int((self / 60.0).rounded(.up))
        if totalMinutes >= 60 {
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(max(1, totalMinutes))m"
    }
}

// MARK: - Color Hex Initializer & Conversion

public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 110, 91, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Safe Array Subscript

public extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Constant URL Helper

public extension URL {
    static func constant(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid constant URL: \(string)")
        }
        return url
    }
}

// MARK: - Date Formatting Helpers

public enum CineVerseDateFormatters {
    public static let isoDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    public static let mediumDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public static let dayAndMonthDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    public static let monthShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}
