import Foundation

public enum IAFlexibleStringOrInt: Decodable, Sendable {
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else if let arrayVal = try? container.decode([String].self), let first = arrayVal.first {
            self = .string(first)
        } else {
            self = .string("")
        }
    }

    public var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .string(let text): return Int(text.trimmingCharacters(in: .whitespaces))
        }
    }

    public var stringValue: String {
        switch self {
        case .int(let value): return String(value)
        case .string(let text): return text
        }
    }
}

public struct IAArchiveSearchResponseDTO: Decodable, Sendable {
    public let response: IAArchiveSearchBodyDTO
}

public struct IAArchiveSearchBodyDTO: Decodable, Sendable {
    public let docs: [IAArchiveSearchDocDTO]
}

public struct IAArchiveSearchDocDTO: Decodable, Sendable {
    public let identifier: String
    public let title: IAFlexibleStringOrInt?
    public let year: IAFlexibleStringOrInt?
}

public struct IAMetadataResponseDTO: Decodable, Sendable {
    public let files: [IAFileDTO]?
}

public struct IAFileDTO: Decodable, Sendable {
    public let name: String
    public let format: String?
    public let height: IAFlexibleStringOrInt?
    public let width: IAFlexibleStringOrInt?
    public let size: IAFlexibleStringOrInt?
}
