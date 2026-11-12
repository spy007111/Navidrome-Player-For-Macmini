import Foundation
import AppKit

@MainActor
public final class AudioCacheManager {
    public static let shared = AudioCacheManager()
    
    private let cacheDir: URL
    private var activeDownloads: Set<String> = []
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = caches.appendingPathComponent("AppleMusicPlayer/audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    public func cachedFileURL(for trackId: String, format: String?) -> URL? {
        let ext = format?.lowercased() ?? "mp3"
        let safeName = sanitize(trackId)
        let fileURL = cacheDir.appendingPathComponent("\(safeName).\(ext)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Ensure file is not 0 bytes
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64, size > 1024 {
                return fileURL
            }
        }
        return nil
    }
    
    public func downloadTrack(track: Track) async throws -> URL {
        let ext = track.format?.lowercased() ?? "mp3"
        let safeName = sanitize(track.id)
        let targetURL = cacheDir.appendingPathComponent("\(safeName).\(ext)")
        
        if let existing = cachedFileURL(for: track.id, format: ext) {
            return existing
        }
        
        guard let streamURL = track.playbackURL else {
            throw NSError(domain: "AudioCache", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的音频链接"])
        }
        
        let session = await NavidromeClient.shared.session
        let (data, response) = try await session.data(from: streamURL)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "AudioCache", code: code, userInfo: [NSLocalizedDescriptionKey: "下载音频失败 HTTP \(code)"])
        }
        
        try data.write(to: targetURL, options: .atomic)
        return targetURL
    }
    
    private func sanitize(_ string: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return string.components(separatedBy: invalid).joined(separator: "_")
    }
}
