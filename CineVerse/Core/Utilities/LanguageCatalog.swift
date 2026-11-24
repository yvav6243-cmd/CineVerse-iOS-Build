import Foundation

public struct LanguageOption: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String

    public var id: String { code }
}

public struct CountryOption: Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String

    public var id: String { code }
}

public enum LanguageCatalog {
    public static let audioAndSubtitleLanguages: [LanguageOption] = [
        LanguageOption(code: "en", name: "English"),
        LanguageOption(code: "ru", name: "Russian"),
        LanguageOption(code: "kk", name: "Kazakh"),
        LanguageOption(code: "ja", name: "Japanese"),
        LanguageOption(code: "ko", name: "Korean"),
        LanguageOption(code: "zh", name: "Chinese"),
        LanguageOption(code: "uk", name: "Ukrainian"),
        LanguageOption(code: "de", name: "German"),
        LanguageOption(code: "fr", name: "French"),
        LanguageOption(code: "es", name: "Spanish"),
        LanguageOption(code: "it", name: "Italian"),
        LanguageOption(code: "pt", name: "Portuguese"),
        LanguageOption(code: "tr", name: "Turkish"),
        LanguageOption(code: "hi", name: "Hindi"),
        LanguageOption(code: "th", name: "Thai"),
        LanguageOption(code: "ar", name: "Arabic"),
        LanguageOption(code: "pl", name: "Polish"),
        LanguageOption(code: "sv", name: "Swedish"),
        LanguageOption(code: "no", name: "Norwegian"),
        LanguageOption(code: "da", name: "Danish"),
        LanguageOption(code: "fi", name: "Finnish"),
        LanguageOption(code: "nl", name: "Dutch"),
        LanguageOption(code: "cs", name: "Czech"),
        LanguageOption(code: "el", name: "Greek"),
        LanguageOption(code: "he", name: "Hebrew"),
        LanguageOption(code: "id", name: "Indonesian"),
        LanguageOption(code: "vi", name: "Vietnamese"),
        LanguageOption(code: "uz", name: "Uzbek"),
        LanguageOption(code: "az", name: "Azerbaijani"),
        LanguageOption(code: "ka", name: "Georgian"),
        LanguageOption(code: "hy", name: "Armenian"),
        LanguageOption(code: "ro", name: "Romanian"),
        LanguageOption(code: "hu", name: "Hungarian"),
        LanguageOption(code: "fa", name: "Persian"),
        LanguageOption(code: "tl", name: "Tagalog")
    ]

    public static let contentMetadataLanguages: [LanguageOption] = [
        LanguageOption(code: "en-US", name: "English (US)"),
        LanguageOption(code: "ru-RU", name: "Russian"),
        LanguageOption(code: "kk-KZ", name: "Kazakh"),
        LanguageOption(code: "ja-JP", name: "Japanese"),
        LanguageOption(code: "ko-KR", name: "Korean"),
        LanguageOption(code: "uk-UA", name: "Ukrainian"),
        LanguageOption(code: "de-DE", name: "German"),
        LanguageOption(code: "fr-FR", name: "French"),
        LanguageOption(code: "es-ES", name: "Spanish")
    ]

    public static let countryCodes: [String] = [
        "US", "GB", "JP", "KR", "CN", "TW", "TH", "FR", "DE", "IT",
        "ES", "CA", "AU", "IN", "RU", "KZ", "UA", "TR", "BR", "MX",
        "SE", "NO", "DK", "FI", "NL", "BE", "PL", "CZ", "IE", "NZ",
        "HK", "SG", "ID", "PH", "AR", "CL", "CO", "EG", "IL", "AE"
    ]

    public static var countries: [CountryOption] {
        countryCodes.map { code in
            let name = Locale.current.localizedString(forRegionCode: code) ?? code
            return CountryOption(code: code, name: name)
        }
        .sorted { $0.name < $1.name }
    }

    public static func displayName(forLanguageCode code: String) -> String {
        if code == "off" { return "Off" }
        let normalized = code.split(separator: "-").first.map(String.init)?.lowercased() ?? code.lowercased()
        if let match = audioAndSubtitleLanguages.first(where: { $0.code == normalized }) {
            return match.name
        }
        return Locale.current.localizedString(forLanguageCode: normalized)?.capitalized ?? code.uppercased()
    }
}
