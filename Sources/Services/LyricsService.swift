import Foundation
import AVFoundation

public struct LyricWordItem: Identifiable, Equatable {
    public let id = UUID()
    public let time: TimeInterval
    public let text: String
    
    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public struct LyricLineItem: Identifiable, Equatable {
    public let id = UUID()
    public let time: TimeInterval
    public let text: String
    public var words: [LyricWordItem]?
    
    public init(time: TimeInterval, text: String, words: [LyricWordItem]? = nil) {
        self.time = time
        self.text = text
        self.words = words
    }
}

@MainActor
public class LyricsService {
    public static let shared = LyricsService()
    
    private init() {}
    
    public func fetchLyrics(for track: Track) async -> (isSynced: Bool, lines: [LyricLineItem]) {
        switch track.source {
        case .local(let path):
            return await fetchLocalLyrics(audioPath: path)
        case .navidrome:
            let (synced, rawLines) = await NavidromeClient.shared.getLyrics(for: track)
            let items = rawLines.map { item -> LyricLineItem in
                let (cleanText, words) = parseWordTimestamps(item.text, baseTime: item.time)
                return LyricLineItem(time: item.time, text: cleanText, words: words)
            }
            return (synced, items)
        }
    }
    
    private func fetchLocalLyrics(audioPath: String) async -> (isSynced: Bool, lines: [LyricLineItem]) {
        let audioURL = URL(fileURLWithPath: audioPath)
        let lrcURL = audioURL.deletingPathExtension().appendingPathExtension("lrc")
        
        // 1. Check for companion .lrc file
        if FileManager.default.fileExists(atPath: lrcURL.path),
           let content = try? String(contentsOf: lrcURL, encoding: .utf8) {
            return parseLRC(content)
        }
        
        // 2. Check for embedded metadata lyrics (USLT)
        let asset = AVURLAsset(url: audioURL)
        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                let key = item.commonKey?.rawValue ?? ""
                if key.contains("lyrics") || key.contains("description") {
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        return parseLRC(stringVal)
                    }
                }
            }
        }
        
        return (false, [])
    }
    
    public func parseLRC(_ content: String) -> (isSynced: Bool, lines: [LyricLineItem]) {
        var lines: [LyricLineItem] = []
        let pattern = "\\[(\\d{1,2}):(\\d{2}(?:\\.\\d{1,3})?)\\](.*)"
        let offsetPattern = "\\[offset:\\s*([+-]?\\d+)\\]"
        let offsetRegex = try? NSRegularExpression(pattern: offsetPattern, options: .caseInsensitive)
        var offsetSeconds: TimeInterval = 0.0
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            let plain = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { LyricLineItem(time: 0, text: $0) }
            return (false, plain)
        }
        
        var hasTimestamp = false
        let rawLines = content.components(separatedBy: .newlines)
        
        // First pass: check for [offset:xxx] tag (in milliseconds; positive means lyrics shifted earlier)
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let offsetRegex = offsetRegex,
               let match = offsetRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)),
               let valStr = Range(match.range(at: 1), in: trimmed).map({ String(trimmed[$0]) }),
               let ms = Double(valStr) {
                offsetSeconds = ms / 1000.0
                break
            }
        }
        
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let nsString = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
            
            if !matches.isEmpty {
                // Support multi-timestamp LRC lines like [00:12.00][01:05.00]Lyric text
                var textPart = trimmed
                if let lastMatch = matches.last {
                    textPart = nsString.substring(with: lastMatch.range(at: 3)).trimmingCharacters(in: .whitespaces)
                }
                
                for match in matches {
                    hasTimestamp = true
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    
                    if let mins = Double(minStr), let secs = Double(secStr) {
                        let totalSeconds = max(0, mins * 60 + secs - offsetSeconds)
                        let (cleanText, words) = parseWordTimestamps(textPart, baseTime: totalSeconds, offsetSeconds: offsetSeconds)
                        lines.append(LyricLineItem(time: totalSeconds, text: cleanText, words: words))
                    }
                }
            } else if !trimmed.hasPrefix("[") {
                lines.append(LyricLineItem(time: 0, text: trimmed))
            }
        }
        
        lines.sort { $0.time < $1.time }
        return (hasTimestamp, lines)
    }
    
    public func parseWordTimestamps(_ raw: String, baseTime: TimeInterval, offsetSeconds: TimeInterval = 0.0) -> (String, [LyricWordItem]?) {
        let wordPattern = "<(\\d{1,2}):(\\d{2}(?:\\.\\d{1,3})?)>([^<]*)"
        guard let wordRegex = try? NSRegularExpression(pattern: wordPattern) else {
            return (raw, nil)
        }
        
        let ns = raw as NSString
        let matches = wordRegex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else {
            return (raw, nil)
        }
        
        var words: [LyricWordItem] = []
        var clean = ""
        for m in matches {
            let mStr = ns.substring(with: m.range(at: 1))
            let sStr = ns.substring(with: m.range(at: 2))
            let wText = ns.substring(with: m.range(at: 3))
            if let mins = Double(mStr), let secs = Double(sStr) {
                let wordTime = max(0, mins * 60 + secs - offsetSeconds)
                words.append(LyricWordItem(time: wordTime, text: wText))
                clean.append(wText)
            }
        }
        return (clean.isEmpty ? raw : clean, words.isEmpty ? nil : words)
    }
}
