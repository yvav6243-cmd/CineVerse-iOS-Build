import Foundation

public struct ImportedLocalFileInfo: Sendable {
    public let relativePath: String
    public let fileName: String
    public let byteSize: Int64
}

public final class LocalVideoStore: @unchecked Sendable {
    public static let shared = LocalVideoStore()

    private let fileManager: FileManager
    private let baseAppSupportURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseAppSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }

    public var videosDirectoryURL: URL {
        baseAppSupportURL.appendingPathComponent("Videos", isDirectory: true)
    }

    public var subtitlesDirectoryURL: URL {
        baseAppSupportURL.appendingPathComponent("Subtitles", isDirectory: true)
    }

    public func importVideo(from securityScopedURL: URL) throws -> ImportedLocalFileInfo {
        try copySecurityScopedFile(from: securityScopedURL, into: videosDirectoryURL, folderPrefix: "Videos")
    }

    public func importSubtitle(from securityScopedURL: URL) throws -> ImportedLocalFileInfo {
        try copySecurityScopedFile(from: securityScopedURL, into: subtitlesDirectoryURL, folderPrefix: "Subtitles")
    }

    public func resolveURL(forRelativePath relativePath: String) -> URL {
        baseAppSupportURL.appendingPathComponent(relativePath)
    }

    public func fileExists(relativePath: String) -> Bool {
        fileManager.fileExists(atPath: resolveURL(forRelativePath: relativePath).path)
    }

    public func deleteFile(relativePath: String) {
        let url = resolveURL(forRelativePath: relativePath)
        try? fileManager.removeItem(at: url)
    }

    public func listVideoFiles() -> [(relativePath: String, fileName: String, sizeBytes: Int64)] {
        listFiles(in: videosDirectoryURL, folderPrefix: "Videos")
    }

    public func totalVideosSizeBytes() -> Int64 {
        listVideoFiles().reduce(0) { $0 + $1.sizeBytes }
    }

    public func totalSubtitlesSizeBytes() -> Int64 {
        listFiles(in: subtitlesDirectoryURL, folderPrefix: "Subtitles").reduce(0) { $0 + $1.sizeBytes }
    }

    public func clearSubtitles() {
        for item in listFiles(in: subtitlesDirectoryURL, folderPrefix: "Subtitles") {
            deleteFile(relativePath: item.relativePath)
        }
    }

    private func copySecurityScopedFile(
        from sourceURL: URL,
        into directoryURL: URL,
        folderPrefix: String
    ) throws -> ImportedLocalFileInfo {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension.lowercased()
        let storedFileName = "\(UUID().uuidString).\(ext)"
        var destinationURL = directoryURL.appendingPathComponent(storedFileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? destinationURL.setResourceValues(resourceValues)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destinationURL.path
        )

        let attrs = try? fileManager.attributesOfItem(atPath: destinationURL.path)
        let byteSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

        return ImportedLocalFileInfo(
            relativePath: "\(folderPrefix)/\(storedFileName)",
            fileName: sourceURL.lastPathComponent,
            byteSize: byteSize
        )
    }

    private func listFiles(in directoryURL: URL, folderPrefix: String) -> [(relativePath: String, fileName: String, sizeBytes: Int64)] {
        guard let items = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return []
        }
        return items.map { url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return (
                relativePath: "\(folderPrefix)/\(url.lastPathComponent)",
                fileName: url.lastPathComponent,
                sizeBytes: Int64(size)
            )
        }
    }
}
