import Foundation
import CryptoKit

public actor ResponseDiskCache {
    private struct Envelope: Codable {
        let storedAt: Date
        let payload: Data
    }

    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directoryURL = base.appendingPathComponent("Responses", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func load<T: Decodable & Sendable>(
        key: String,
        maxAge: TimeInterval,
        as type: T.Type
    ) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(envelope.storedAt) <= maxAge else {
            return nil
        }
        return try? decoder.decode(type, from: envelope.payload)
    }

    public func loadEvenIfStale<T: Decodable & Sendable>(
        key: String,
        as type: T.Type
    ) -> T? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return nil
        }
        return try? decoder.decode(type, from: envelope.payload)
    }

    public func store<T: Encodable & Sendable>(_ value: T, forKey key: String) {
        guard let payload = try? encoder.encode(value) else { return }
        let envelope = Envelope(storedAt: Date(), payload: payload)
        guard let wrapped = try? encoder.encode(envelope) else { return }
        let url = fileURL(for: key)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? wrapped.write(to: url, options: .atomic)
    }

    public func clear() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    public func sizeBytes() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for file in files {
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directoryURL.appendingPathComponent("\(name).json")
    }
}
