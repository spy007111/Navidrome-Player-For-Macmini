import Foundation
import AVFoundation
import AppKit
import CryptoKit

@MainActor
public class LocalLibraryManager: ObservableObject {
    public static let shared = LocalLibraryManager()
    
    @Published public var tracks: [Track] = []
    @Published public var albums: [Album] = []
    @Published public var artists: [Artist] = []
    @Published public var isScanning: Bool = false
    @Published public var scanStatus: String = ""
    @Published public var scanProgress: Double = 0.0
    @Published public var musicFolders: [String] = []
    
    private let supportedExtensions: Set<String> = ["mp3", "m4a", "flac", "wav", "aac", "aiff", "alac", "ogg"]
    private let cacheFileURL: URL
    private let coversDir: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AppleMusicPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheFileURL = dir.appendingPathComponent("local_library.json")
        
        self.coversDir = dir.appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        
        // Safeguard: purge oversized/bloated legacy cache file (> 20MB)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFileURL.path),
           let size = attrs[.size] as? Int64, size > 20 * 1024 * 1024 {
            print("[LocalLibraryManager] Purging oversized cache file of \(size / 1024 / 1024) MB")
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
        
        loadSavedFolders()
        loadCachedLibraryAsync()
    }
    
    private func loadSavedFolders() {
        if let saved = UserDefaults.standard.stringArray(forKey: "AppleMusicPlayer.MusicFolders"), !saved.isEmpty {
            self.musicFolders = saved
        } else {
            let defaultMusic = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first?.path
            if let musicPath = defaultMusic, FileManager.default.fileExists(atPath: musicPath) {
                self.musicFolders = [musicPath]
            }
        }
    }
    
    public func addFolder(path: String) {
        guard !musicFolders.contains(path) else { return }
        musicFolders.append(path)
        UserDefaults.standard.set(musicFolders, forKey: "AppleMusicPlayer.MusicFolders")
        Task {
            await scanAllFolders()
        }
    }
    
    public func removeFolder(path: String) {
        musicFolders.removeAll { $0 == path }
        UserDefaults.standard.set(musicFolders, forKey: "AppleMusicPlayer.MusicFolders")
        Task {
            await scanAllFolders()
        }
    }
    
    public func scanAllFolders() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        scanStatus = "准备扫描本地音乐库..."
        
        let foldersToScan = self.musicFolders
        
        // Run filesystem enumeration and parsing in background
        let scannedTracks: [Track] = await Task.detached(priority: .userInitiated) { [weak self] () -> [Track] in
            guard let self = self else { return [] }
            var foundURLs: [URL] = []
            for folder in foldersToScan {
                let url = URL(fileURLWithPath: folder)
                foundURLs.append(contentsOf: self.findAudioFiles(in: url))
            }
            
            var results: [Track] = []
            let total = foundURLs.count
            for (index, fileURL) in foundURLs.enumerated() {
                Task { @MainActor [weak self] in
                    self?.scanProgress = Double(index) / Double(max(total, 1))
                    self?.scanStatus = "正在分析: \(fileURL.lastPathComponent) (\(index + 1)/\(total))"
                }
                if let track = await self.parseTrack(from: fileURL) {
                    results.append(track)
                }
            }
            return results
        }.value
        
        self.tracks = scannedTracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        buildAlbumsAndArtists(from: scannedTracks)
        
        self.isScanning = false
        self.scanProgress = 1.0
        self.scanStatus = "扫描完成，共找到 \(scannedTracks.count) 首歌曲"
        saveToCache()
    }
    
    private nonisolated func findAudioFiles(in directoryURL: URL) -> [URL] {
        var results: [URL] = []
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        return results
    }
    
    private nonisolated func parseTrack(from fileURL: URL) async -> Track? {
        let asset = AVURLAsset(url: fileURL)
        var duration: TimeInterval = 0
        if let dur = try? await asset.load(.duration) {
            duration = CMTimeGetSeconds(dur)
        }
        
        var title = fileURL.deletingPathExtension().lastPathComponent
        var artist = "未知艺人"
        var album = "未知专辑"
        var trackNumber: Int?
        var year: Int?
        var genre: String?
        var coverPath: String?
        
        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                guard let key = item.commonKey?.rawValue else { continue }
                if key == AVMetadataKey.commonKeyTitle.rawValue {
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        title = stringVal
                    }
                } else if key == AVMetadataKey.commonKeyArtist.rawValue {
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        artist = stringVal
                    }
                } else if key == AVMetadataKey.commonKeyAlbumName.rawValue {
                    if let stringVal = try? await item.load(.stringValue), !stringVal.isEmpty {
                        album = stringVal
                    }
                } else if key == AVMetadataKey.commonKeyArtwork.rawValue {
                    if let data = try? await item.load(.dataValue) {
                        coverPath = saveArtworkThumbnail(data: data)
                    }
                } else if key == AVMetadataKey.commonKeyType.rawValue {
                    if let stringVal = try? await item.load(.stringValue) {
                        genre = stringVal
                    }
                }
            }
        }
        
        // Also check format metadata for track number / year if missing
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                if let items = try? await asset.loadMetadata(for: format) {
                    for item in items {
                        let keyString = item.identifier?.rawValue ?? ""
                        if keyString.contains("trackNumber") || keyString.contains("TRCK") {
                            if let stringVal = try? await item.load(.stringValue) {
                                let parts = stringVal.components(separatedBy: "/")
                                trackNumber = Int(parts[0].trimmingCharacters(in: .whitespaces))
                            }
                        } else if keyString.contains("year") || keyString.contains("TYER") || keyString.contains("TDRC") {
                            if let stringVal = try? await item.load(.stringValue),
                               let yr = Int(stringVal.prefix(4)) {
                                year = yr
                            }
                        }
                    }
                }
            }
        }
        
        return Track(
            id: fileURL.path,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            trackNumber: trackNumber,
            discNumber: nil,
            year: year,
            genre: genre,
            source: .local(path: fileURL.path),
            coverArtPath: coverPath,
            format: fileURL.pathExtension.uppercased()
        )
    }
    
    private nonisolated func saveArtworkThumbnail(data: Data) -> String? {
        let hash = Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        let fileURL = coversDir.appendingPathComponent("\(hash).jpg")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL.path
        }
        
        guard let image = NSImage(data: data) else { return nil }
        
        // Downscale to max 300x300 for blazing fast rendering and tiny disk footprint
        let maxDim: CGFloat = 300
        let origSize = image.size
        guard origSize.width > 0, origSize.height > 0 else { return nil }
        
        let scale = min(maxDim / origSize.width, maxDim / origSize.height, 1.0)
        let targetSize = CGSize(width: origSize.width * scale, height: origSize.height * scale)
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            NSGraphicsContext.restoreGraphicsState()
            
            if let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) {
                try? jpeg.write(to: fileURL)
                return fileURL.path
            }
        } else {
            NSGraphicsContext.restoreGraphicsState()
        }
        return nil
    }
    
    private func buildAlbumsAndArtists(from tracks: [Track]) {
        var albumDict: [String: [Track]] = [:]
        for track in tracks {
            let key = "\(track.album)___\(track.artist)"
            albumDict[key, default: []].append(track)
        }
        
        var newAlbums: [Album] = []
        for (_, albumTracks) in albumDict {
            guard let first = albumTracks.first else { continue }
            let totalDur = albumTracks.reduce(0.0) { $0 + $1.duration }
            let coverPath = albumTracks.first(where: { $0.coverArtPath != nil })?.coverArtPath
            
            newAlbums.append(
                Album(
                    id: "local_album_\(first.album)_\(first.artist)",
                    title: first.album,
                    artist: first.artist,
                    year: first.year,
                    genre: first.genre,
                    songCount: albumTracks.count,
                    duration: totalDur,
                    coverArtPath: coverPath,
                    isNavidrome: false
                )
            )
        }
        self.albums = newAlbums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        
        var artistDict: [String: Set<String>] = [:]
        for track in tracks {
            artistDict[track.artist, default: []].insert(track.album)
        }
        
        var newArtists: [Artist] = []
        for (artistName, albumSet) in artistDict {
            newArtists.append(
                Artist(
                    id: "local_artist_\(artistName)",
                    name: artistName,
                    albumCount: albumSet.count,
                    isNavidrome: false
                )
            )
        }
        self.artists = newArtists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private func saveToCache() {
        struct CacheData: Codable {
            let tracks: [Track]
            let albums: [Album]
            let artists: [Artist]
        }
        let cache = CacheData(tracks: self.tracks, albums: self.albums, artists: self.artists)
        Task.detached(priority: .utility) { [cache, cacheFileURL = self.cacheFileURL] in
            if let data = try? JSONEncoder().encode(cache) {
                try? data.write(to: cacheFileURL, options: .atomic)
            }
        }
    }
    
    private func loadCachedLibraryAsync() {
        Task {
            let cached = await Task.detached(priority: .userInitiated) { [cacheFileURL = self.cacheFileURL] () -> (tracks: [Track], albums: [Album], artists: [Artist])? in
                guard FileManager.default.fileExists(atPath: cacheFileURL.path),
                      let data = try? Data(contentsOf: cacheFileURL) else { return nil }
                
                struct CacheData: Codable {
                    let tracks: [Track]
                    let albums: [Album]
                    let artists: [Artist]
                }
                
                if let cache = try? JSONDecoder().decode(CacheData.self, from: data) {
                    return (cache.tracks, cache.albums, cache.artists)
                }
                return nil
            }.value
            
            if let cached = cached {
                self.tracks = cached.tracks
                self.albums = cached.albums
                self.artists = cached.artists
            }
        }
    }
}
