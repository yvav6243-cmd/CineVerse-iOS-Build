import Foundation

public enum SubtitleParsers {
    public static func parse(text: String, format: SubtitleFormat) -> [SubtitleCue] {
        switch format {
        case .srt:
            return parseSRT(text)
        case .webVTT:
            return parseWebVTT(text)
        case .embeddedHLS:
            return parseWebVTT(text)
        }
    }

    public static func parseSRT(_ raw: String) -> [SubtitleCue] {
        let blocks = splitBlocks(raw)
        var cues: [SubtitleCue] = []
        cues.reserveCapacity(blocks.count)

        for block in blocks {
            var lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            // Optional numeric cue index on line 0
            if !lines[0].contains("-->"), lines.count >= 2, lines[1].contains("-->") {
                lines.removeFirst()
            }

            guard let timingLine = lines.first,
                  let (start, end) = parseTimingLine(timingLine) else {
                continue
            }

            let textLines = Array(lines.dropFirst())
            let cleaned = cleanCueText(textLines.joined(separator: "\n"))
            guard !cleaned.isEmpty else { continue }

            cues.append(SubtitleCue(id: cues.count, startTime: start, endTime: end, text: cleaned))
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    public static func parseWebVTT(_ raw: String) -> [SubtitleCue] {
        let blocks = splitBlocks(raw)
        var cues: [SubtitleCue] = []
        cues.reserveCapacity(blocks.count)

        for block in blocks {
            let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBlock.isEmpty { continue }
            if trimmedBlock.hasPrefix("WEBVTT")
                || trimmedBlock.hasPrefix("NOTE")
                || trimmedBlock.hasPrefix("STYLE")
                || trimmedBlock.hasPrefix("REGION") {
                continue
            }

            var lines = trimmedBlock
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            // Optional cue identifier before timing line
            if !lines[0].contains("-->"), lines.count >= 2, lines[1].contains("-->") {
                lines.removeFirst()
            }

            guard let timingLine = lines.first,
                  let (start, end) = parseTimingLine(timingLine) else {
                continue
            }

            let textLines = Array(lines.dropFirst())
            let cleaned = cleanCueText(textLines.joined(separator: "\n"))
            guard !cleaned.isEmpty else { continue }

            cues.append(SubtitleCue(id: cues.count, startTime: start, endTime: end, text: cleaned))
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    private static func splitBlocks(_ raw: String) -> [String] {
        var normalized = raw
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        normalized = normalized
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n\n")
    }

    private static func parseTimingLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startRaw = parts[0].trimmingCharacters(in: .whitespaces)
        // Strip cue settings after end timestamp (e.g. "00:01:02.000 align:start position:10%")
        let endRaw = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", maxSplits: 1)
            .first
            .map(String.init) ?? ""

        guard let start = parseTimestamp(startRaw),
              let end = parseTimestamp(endRaw),
              end >= start else {
            return nil
        }
        return (start, end)
    }

    public static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let unified = raw.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let components = unified.split(separator: ":")
        guard components.count == 2 || components.count == 3 else { return nil }

        let secondsPartString = String(components[components.count - 1])
        guard let secondsAndMillis = Double(secondsPartString) else { return nil }

        if components.count == 3 {
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]) else { return nil }
            return hours * 3600 + minutes * 60 + secondsAndMillis
        } else {
            guard let minutes = Double(components[0]) else { return nil }
            return minutes * 60 + secondsAndMillis
        }
    }

    private static func cleanCueText(_ raw: String) -> String {
        var result = raw
        let tagPatterns = [
            "\\{\\\\[^}]*\\}",
            "</?(i|b|u|c|v|lang)[^>]*>"
        ]
        for pattern in tagPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
