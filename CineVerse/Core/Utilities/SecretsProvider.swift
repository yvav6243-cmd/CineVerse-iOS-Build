import Foundation

public enum TMDBCredential: Sendable, Equatable {
    case apiKey(String)
    case bearer(String)

    public var rawValue: String {
        switch self {
        case .apiKey(let value), .bearer(let value):
            return value
        }
    }
}

public enum SecretsProvider {
    private static let tmdbKeychainAccount = "tmdb_api_credential"

    public static func tmdbCredential() -> TMDBCredential? {
        if let keychainValue = KeychainStore.shared.string(forAccount: tmdbKeychainAccount)?.nilIfEmpty {
            return classifyTMDB(keychainValue)
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "your_tmdb_v3_or_v4_key_here" {
                return classifyTMDB(trimmed)
            }
        }
        return nil
    }

    public static func saveTMDBCredential(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try KeychainStore.shared.delete(forAccount: tmdbKeychainAccount)
            return
        }
        try KeychainStore.shared.set(trimmed, forAccount: tmdbKeychainAccount)
    }

    public static func removeTMDBCredential() throws {
        try KeychainStore.shared.delete(forAccount: tmdbKeychainAccount)
    }

    public static func hasKeychainTMDBCredential() -> Bool {
        KeychainStore.shared.string(forAccount: tmdbKeychainAccount)?.nilIfEmpty != nil
    }

    private static func classifyTMDB(_ token: String) -> TMDBCredential {
        let cleaned = token.replacingOccurrences(of: "Bearer ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 40 {
            return .apiKey(cleaned)
        }
        return .bearer(cleaned)
    }
}
