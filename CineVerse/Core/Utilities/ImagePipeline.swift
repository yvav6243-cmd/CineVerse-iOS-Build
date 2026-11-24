import UIKit
import ImageIO
import CryptoKit

public actor ImagePipeline {
    public static let shared = ImagePipeline()

    private let memoryCache: NSCache<NSString, UIImage>
    private let diskDirectory: URL
    private let fileManager: FileManager
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 120 * 1024 * 1024
        self.memoryCache = cache

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.diskDirectory = caches.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    public func image(for url: URL, targetSize: CGSize, scale: CGFloat) async -> UIImage? {
        guard url.scheme?.lowercased() == "https" || url.isFileURL else {
            return nil
        }

        let maxDimension = max(Int(max(targetSize.width, targetSize.height) * max(scale, 1)), 64)
        let key = "\(url.absoluteString)|\(maxDimension)"

        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        if let existingTask = inFlight[key] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            await loadAndDecode(url: url, cacheKey: key, maxPixelSize: maxDimension)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    public func fetchRawData(for url: URL) async -> Data? {
        guard url.scheme?.lowercased() == "https" else { return nil }
        let file = diskFileURL(for: url)
        if let data = try? Data(contentsOf: file) {
            return data
        }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        return data
    }

    public func clearDiskCache() {
        memoryCache.removeAllObjects()
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    public func diskSizeBytes() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskDirectory,
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

    private func loadAndDecode(url: URL, cacheKey: String, maxPixelSize: Int) async -> UIImage? {
        let data: Data?
        if url.isFileURL {
            data = try? Data(contentsOf: url)
        } else {
            data = await fetchRawData(for: url)
        }

        guard let data,
              let decoded = Self.downsample(data: data, maxPixelSize: maxPixelSize) else {
            return nil
        }

        let cost = Int(decoded.size.width * decoded.size.height * decoded.scale * decoded.scale * 4)
        memoryCache.setObject(decoded, forKey: cacheKey as NSString, cost: max(cost, 1))
        return decoded
    }

    private func diskFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent("\(name).img")
    }

    nonisolated private static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
