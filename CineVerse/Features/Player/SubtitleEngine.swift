import Foundation
import Observation

@MainActor
@Observable
public final class SubtitleEngine {
    public private(set) var cues: [SubtitleCue] = []
    public private(set) var currentText: String?
    public private(set) var loadError: String?

    private let httpClient: HTTPClient
    private let maxSubtitleBytes = 5 * 1024 * 1024

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func loadExternal(url: URL, format: SubtitleFormat) async {
        loadError = nil
        currentText = nil

        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                guard url.scheme?.lowercased() == "https" else {
                    loadError = "Subtitle URL must use HTTPS."
                    return
                }
                let ep = Endpoint(baseURL: url, path: "", method: .get, timeoutInterval: 15)
                let (fetched, _) = try await httpClient.data(ep)
                data = fetched
            }

            guard data.count <= maxSubtitleBytes else {
                loadError = "Subtitle file exceeds 5 MB limit."
                return
            }

            let decodedText = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .utf16)
                ?? String(data: data, encoding: .isoLatin1)

            guard let decodedText else {
                loadError = "Unsupported subtitle text encoding."
                return
            }

            let parsed = await Task.detached(priority: .userInitiated) {
                SubtitleParsers.parse(text: decodedText, format: format)
            }.value

            cues = parsed
        } catch {
            loadError = error.localizedDescription
            cues = []
        }
    }

    public func clear() {
        cues = []
        currentText = nil
        loadError = nil
    }

    public func update(forTime time: TimeInterval) {
        guard !cues.isEmpty else {
            if currentText != nil { currentText = nil }
            return
        }

        // Binary search for the rightmost cue whose startTime <= time
        var low = 0
        var high = cues.count - 1
        var candidate: Int?

        while low <= high {
            let mid = (low + high) / 2
            if cues[mid].startTime <= time {
                candidate = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        var activeLines: [String] = []
        if let candidate {
            // Check backwards slightly for overlapping cues
            var idx = candidate
            while idx >= 0 && time - cues[idx].startTime < 30 {
                if cues[idx].startTime <= time && time <= cues[idx].endTime {
                    activeLines.insert(cues[idx].text, at: 0)
                }
                idx -= 1
            }
        }

        let newText = activeLines.isEmpty ? nil : activeLines.joined(separator: "\n")
        if newText != currentText {
            currentText = newText
        }
    }
}
