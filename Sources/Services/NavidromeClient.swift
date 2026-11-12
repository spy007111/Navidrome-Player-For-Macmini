import Foundation
import CryptoKit
import AppKit

public final class ImageCache: @unchecked Sendable {
    public static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    public func get(for key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    public func set(_ image: NSImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

public final class InsecureSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    public var allowInsecure: Bool = true
    
    public init(allowInsecure: Bool = true) {
        self.allowInsecure = allowInsecure
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if allowInsecure && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            // Accept self-signed / untrusted certificates
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

public struct NavidromeConfig: Codable, Equatable {
    public var serverURL: String
    public var username: String
    public var password: String
    public var allowInsecureTLS: Bool
    public var usePlaintextAuth: Bool
    
    enum CodingKeys: String, CodingKey {
        case serverURL, username, password, allowInsecureTLS, usePlaintextAuth
    }
    
    public init(
        serverURL: String = "",
        username: String = "",
        password: String = "",
        allowInsecureTLS: Bool = true,
        usePlaintextAuth: Bool = false
    ) {
        self.serverURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
        self.allowInsecureTLS = allowInsecureTLS
        self.usePlaintextAuth = usePlaintextAuth
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.serverURL = try container.decode(String.self, forKey: .serverURL)
        self.username = try container.decode(String.self, forKey: .username)
        self.password = try container.decode(String.self, forKey: .password)
        self.allowInsecureTLS = try container.decodeIfPresent(Bool.self, forKey: .allowInsecureTLS) ?? true
        self.usePlaintextAuth = try container.decodeIfPresent(Bool.self, forKey: .usePlaintextAuth) ?? false
    }
    
    public var isValid: Bool {
        guard !serverURL.isEmpty, !username.isEmpty, !password.isEmpty else { return false }
        return URL(string: serverURL) != nil
    }
    
    private static let key = "AppleMusicPlayer.NavidromeConfig"
    
    public static func load() -> NavidromeConfig? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(NavidromeConfig.self, from: data) else {
            return nil
        }
        return config
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: NavidromeConfig.key)
        }
    }
    
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

public actor NavidromeClient {
    public static let shared = NavidromeClient()
    
    private var config: NavidromeConfig?
    public private(set) var session: URLSession
    private var sessionDelegate: InsecureSessionDelegate
    
    private init() {
        let savedConfig = NavidromeConfig.load()
        self.config = savedConfig
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        
        let delegate = InsecureSessionDelegate(allowInsecure: savedConfig?.allowInsecureTLS ?? true)
        self.sessionDelegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    public func setConfig(_ newConfig: NavidromeConfig) {
        self.config = newConfig
        newConfig.save()
        rebuildSession()
    }
    
    private func rebuildSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        
        let allowInsecure = config?.allowInsecureTLS ?? true
        let delegate = InsecureSessionDelegate(allowInsecure: allowInsecure)
        self.sessionDelegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    public func getConfig() -> NavidromeConfig? {
        return config
    }
    
    public func isConfigured() -> Bool {
        return config?.isValid ?? false
    }
    
    // MARK: - Auth & URL Building
    private func buildURL(endpoint: String, additionalParams: [URLQueryItem] = [], forcePlaintext: Bool? = nil) throws -> URL {
        guard let config = self.config, config.isValid else {
            throw SubsonicError(code: 10, message: "Navidrome 服务器未配置")
        }
        
        var cleanURL = config.serverURL
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        guard var components = URLComponents(string: "\(cleanURL)/rest/\(endpoint)") else {
            throw SubsonicError(code: 10, message: "无效的服务器地址: \(cleanURL)")
        }
        
        var queryItems = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "AppleMusicMac"),
            URLQueryItem(name: "f", value: "json")
        ]
        
        let usePlaintext = forcePlaintext ?? config.usePlaintextAuth
        if usePlaintext {
            queryItems.append(URLQueryItem(name: "p", value: config.password))
        } else {
            let salt = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased())
            let tokenInput = config.password + salt
            let digest = Insecure.MD5.hash(data: Data(tokenInput.utf8))
            let token = digest.map { String(format: "%02hhx", $0) }.joined()
            queryItems.append(URLQueryItem(name: "t", value: token))
            queryItems.append(URLQueryItem(name: "s", value: salt))
        }
        
        queryItems.append(contentsOf: additionalParams)
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SubsonicError(code: 10, message: "无法生成请求链接")
        }
        
        return url
    }
    
    public nonisolated func getStreamURLString(for songId: String) -> String? {
        guard let config = NavidromeConfig.load(), config.isValid else { return nil }
        
        var cleanURL = config.serverURL
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        var components = URLComponents(string: "\(cleanURL)/rest/stream.view")
        var queryItems = [
            URLQueryItem(name: "id", value: songId),
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "AppleMusicMac")
        ]
        
        if config.usePlaintextAuth {
            queryItems.append(URLQueryItem(name: "p", value: config.password))
        } else {
            let salt = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased())
            let tokenInput = config.password + salt
            let digest = Insecure.MD5.hash(data: Data(tokenInput.utf8))
            let token = digest.map { String(format: "%02hhx", $0) }.joined()
            queryItems.append(URLQueryItem(name: "t", value: token))
            queryItems.append(URLQueryItem(name: "s", value: salt))
        }
        
        components?.queryItems = queryItems
        return components?.url?.absoluteString
    }
    
    public nonisolated func getCoverArtURLString(for coverArtId: String?, size: Int = 600) -> String? {
        guard let coverArtId = coverArtId, !coverArtId.isEmpty,
              let config = NavidromeConfig.load(), config.isValid else { return nil }
        
        var cleanURL = config.serverURL
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        var components = URLComponents(string: "\(cleanURL)/rest/getCoverArt.view")
        var queryItems = [
            URLQueryItem(name: "id", value: coverArtId),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "AppleMusicMac")
        ]
        
        if config.usePlaintextAuth {
            queryItems.append(URLQueryItem(name: "p", value: config.password))
        } else {
            let salt = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased())
            let tokenInput = config.password + salt
            let digest = Insecure.MD5.hash(data: Data(tokenInput.utf8))
            let token = digest.map { String(format: "%02hhx", $0) }.joined()
            queryItems.append(URLQueryItem(name: "t", value: token))
            queryItems.append(URLQueryItem(name: "s", value: salt))
        }
        
        components?.queryItems = queryItems
        return components?.url?.absoluteString
    }
    
    // MARK: - API Calls
    
    public func testConnection() async throws -> (version: String, serverType: String) {
        do {
            return try await executePing(usePlaintext: false)
        } catch let err as SubsonicError {
            if err.code == 40 {
                // Try fallback to plaintext password auth (e.g. for LDAP/Authelia instances)
                if let result = try? await executePing(usePlaintext: true) {
                    if var currentConfig = self.config {
                        currentConfig.usePlaintextAuth = true
                        self.config = currentConfig
                        currentConfig.save()
                    }
                    return result
                }
            }
            throw err
        }
    }
    
    private func executePing(usePlaintext: Bool) async throws -> (version: String, serverType: String) {
        let url = try buildURL(endpoint: "ping.view", forcePlaintext: usePlaintext)
        
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            if urlError.code == .secureConnectionFailed || urlError.code == .serverCertificateUntrusted {
                throw SubsonicError(code: -1200, message: "TLS/SSL 证书校验未通过。请勾选【忽略 SSL/TLS 证书验证】开关后重试。")
            } else if urlError.code == .cannotConnectToHost || urlError.code == .timedOut {
                throw SubsonicError(code: -1004, message: "无法连接至服务器，请检查地址、端口及网络连接: \(urlError.localizedDescription)")
            } else {
                throw SubsonicError(code: urlError.errorCode, message: urlError.localizedDescription)
            }
        } catch {
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubsonicError(code: 0, message: "未收到有效的 HTTP 响应")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw SubsonicError(code: 404, message: "HTTP 404: 未在指定地址找到 Navidrome API (/rest/ping.view)，请检查地址是否正确（如是否包含 /navidrome 等子路径）")
            } else {
                throw SubsonicError(code: httpResponse.statusCode, message: "服务器返回 HTTP 错误码 \(httpResponse.statusCode)")
            }
        }
        
        let wrapper: SubsonicWrapper<EmptyPayload>
        do {
            wrapper = try JSONDecoder().decode(SubsonicWrapper<EmptyPayload>.self, from: data)
        } catch {
            let rawString = String(data: data, encoding: .utf8) ?? "非文本响应"
            throw SubsonicError(code: -1, message: "解析服务器响应失败: \(rawString.prefix(100))")
        }
        
        let resp = wrapper.subsonicResponse
        if resp.status != "ok" {
            let errorMsg = resp.error?.message ?? "未知错误"
            let errorCode = resp.error?.code ?? -1
            throw SubsonicError(code: errorCode, message: errorMsg)
        }
        
        let ver = resp.serverVersion ?? resp.version ?? "1.0"
        let serverType = resp.type ?? "Subsonic/Navidrome"
        return (ver, serverType)
    }
    
    public func getAlbums(type: String = "recent", size: Int = 60, offset: Int = 0) async throws -> [Album] {
        let params = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "size", value: "\(size)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        let url = try buildURL(endpoint: "getAlbumList2.view", additionalParams: params)
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<AlbumListPayload>.self, from: data)
        guard let albums = wrapper.subsonicResponse.data?.albumList2?.album else {
            return []
        }
        
        return albums.map { item in
            Album(
                id: item.id,
                title: item.displayTitle,
                artist: item.artist ?? "未知艺人",
                year: item.year,
                genre: item.genre,
                songCount: item.songCount ?? 0,
                duration: TimeInterval(item.duration ?? 0),
                coverArtURLString: getCoverArtURLString(for: item.coverArt ?? item.id, size: 300),
                isNavidrome: true
            )
        }
    }
    
    public func getSongs(size: Int = 500) async throws -> [Track] {
        let params = [URLQueryItem(name: "size", value: "\(size)")]
        let url = try buildURL(endpoint: "getRandomSongs.view", additionalParams: params)
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<RandomSongsPayload>.self, from: data)
        guard let songItems = wrapper.subsonicResponse.data?.randomSongs?.song else {
            return []
        }
        
        return songItems.map { song in
            let streamURL = getStreamURLString(for: song.id) ?? ""
            let coverURL = getCoverArtURLString(for: song.coverArt ?? song.id, size: 80)
            return Track(
                id: song.id,
                title: song.title,
                artist: song.artist ?? "未知艺人",
                album: song.album ?? "未知专辑",
                duration: TimeInterval(song.duration ?? 0),
                trackNumber: song.track,
                discNumber: song.discNumber,
                year: song.year,
                genre: song.genre,
                source: .navidrome(id: song.id, streamURL: streamURL),
                coverArtURLString: coverURL,
                bitRate: song.bitRate,
                format: song.suffix?.uppercased(),
                isFavorite: song.isStarred
            )
        }
    }
    
    public func getAlbumDetail(albumId: String) async throws -> (album: Album, tracks: [Track]) {
        let params = [URLQueryItem(name: "id", value: albumId)]
        let url = try buildURL(endpoint: "getAlbum.view", additionalParams: params)
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<AlbumDetailPayload>.self, from: data)
        guard let albumData = wrapper.subsonicResponse.data?.album else {
            throw SubsonicError(code: 404, message: "未找到专辑信息")
        }
        
        let album = Album(
            id: albumData.id,
            title: albumData.title ?? albumData.name ?? "未知专辑",
            artist: albumData.artist ?? "未知艺人",
            year: albumData.year,
            genre: albumData.genre,
            songCount: albumData.songCount ?? albumData.song?.count ?? 0,
            duration: TimeInterval(albumData.duration ?? 0),
            coverArtURLString: getCoverArtURLString(for: albumData.coverArt ?? albumData.id),
            isNavidrome: true
        )
        
        let tracks: [Track] = (albumData.song ?? []).map { song in
            let streamURL = getStreamURLString(for: song.id) ?? ""
            let coverURL = getCoverArtURLString(for: song.coverArt ?? albumData.coverArt ?? albumData.id)
            return Track(
                id: song.id,
                title: song.title,
                artist: song.artist ?? album.artist,
                album: song.album ?? album.title,
                duration: TimeInterval(song.duration ?? 0),
                trackNumber: song.track,
                discNumber: song.discNumber,
                year: song.year ?? album.year,
                genre: song.genre ?? album.genre,
                source: .navidrome(id: song.id, streamURL: streamURL),
                coverArtURLString: coverURL,
                bitRate: song.bitRate,
                format: song.suffix?.uppercased(),
                isFavorite: song.isStarred
            )
        }
        
        return (album, tracks)
    }
    
    public func getArtists() async throws -> [Artist] {
        let url = try buildURL(endpoint: "getArtists.view")
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<ArtistsPayload>.self, from: data)
        var artists: [Artist] = []
        if let indexes = wrapper.subsonicResponse.data?.artists?.index {
            for index in indexes {
                if let items = index.artist {
                    for item in items {
                        artists.append(
                            Artist(
                                id: item.id,
                                name: item.name,
                                albumCount: item.albumCount ?? 0,
                                isNavidrome: true,
                                coverArtURLString: getCoverArtURLString(for: item.coverArt ?? item.id)
                            )
                        )
                    }
                }
            }
        }
        return artists
    }
    
    public func getArtistDetail(artistId: String) async throws -> (artist: Artist, albums: [Album]) {
        let params = [URLQueryItem(name: "id", value: artistId)]
        let url = try buildURL(endpoint: "getArtist.view", additionalParams: params)
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<ArtistDetailPayload>.self, from: data)
        guard let artistData = wrapper.subsonicResponse.data?.artist else {
            throw SubsonicError(code: 404, message: "未找到艺人详情")
        }
        
        let artist = Artist(
            id: artistData.id,
            name: artistData.name,
            albumCount: artistData.album?.count ?? 0,
            isNavidrome: true,
            coverArtURLString: getCoverArtURLString(for: artistData.coverArt ?? artistData.id)
        )
        
        let albums: [Album] = (artistData.album ?? []).map { item in
            Album(
                id: item.id,
                title: item.displayTitle,
                artist: item.artist ?? artist.name,
                year: item.year,
                genre: item.genre,
                songCount: item.songCount ?? 0,
                duration: TimeInterval(item.duration ?? 0),
                coverArtURLString: getCoverArtURLString(for: item.coverArt ?? item.id, size: 300),
                isNavidrome: true
            )
        }
        
        return (artist, albums)
    }
    
    public func search(query: String) async throws -> (songs: [Track], albums: [Album], artists: [Artist]) {
        let params = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "songCount", value: "30"),
            URLQueryItem(name: "albumCount", value: "20"),
            URLQueryItem(name: "artistCount", value: "10")
        ]
        let url = try buildURL(endpoint: "search3.view", additionalParams: params)
        let (data, _) = try await session.data(from: url)
        
        let wrapper = try JSONDecoder().decode(SubsonicWrapper<SearchPayload>.self, from: data)
        guard let result = wrapper.subsonicResponse.data?.searchResult3 else {
            return ([], [], [])
        }
        
        let songs: [Track] = (result.song ?? []).map { song in
            let streamURL = getStreamURLString(for: song.id) ?? ""
            let coverURL = getCoverArtURLString(for: song.coverArt ?? song.id, size: 80)
            return Track(
                id: song.id,
                title: song.title,
                artist: song.artist ?? "未知艺人",
                album: song.album ?? "未知专辑",
                duration: TimeInterval(song.duration ?? 0),
                trackNumber: song.track,
                discNumber: song.discNumber,
                year: song.year,
                genre: song.genre,
                source: .navidrome(id: song.id, streamURL: streamURL),
                coverArtURLString: coverURL,
                bitRate: song.bitRate,
                format: song.suffix?.uppercased(),
                isFavorite: song.isStarred
            )
        }
        
        let albums: [Album] = (result.album ?? []).map { item in
            Album(
                id: item.id,
                title: item.displayTitle,
                artist: item.artist ?? "未知艺人",
                year: item.year,
                genre: item.genre,
                songCount: item.songCount ?? 0,
                duration: TimeInterval(item.duration ?? 0),
                coverArtURLString: getCoverArtURLString(for: item.coverArt ?? item.id, size: 300),
                isNavidrome: true
            )
        }
        
        let artists: [Artist] = (result.artist ?? []).map { item in
            Artist(
                id: item.id,
                name: item.name,
                albumCount: item.albumCount ?? 0,
                isNavidrome: true,
                coverArtURLString: getCoverArtURLString(for: item.coverArt ?? item.id)
            )
        }
        
        return (songs, albums, artists)
    }
    
    public func fetchImage(from urlString: String) async -> NSImage? {
        if let cached = ImageCache.shared.get(for: urlString) {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: url)
            if let image = NSImage(data: data) {
                ImageCache.shared.set(image, for: urlString)
                return image
            }
        } catch {
            // Ignore fetch error
        }
        return nil
    }
    
    public func getLyrics(for track: Track) async -> (synced: Bool, lines: [(time: TimeInterval, text: String)]) {
        if case .navidrome(let id, _) = track.source {
            if let lines = await fetchLyricsBySongId(songId: id) {
                return lines
            }
        }
        
        do {
            let params = [
                URLQueryItem(name: "artist", value: track.artist),
                URLQueryItem(name: "title", value: track.title)
            ]
            let url = try buildURL(endpoint: "getLyrics.view", additionalParams: params)
            let (data, _) = try await session.data(from: url)
            let wrapper = try JSONDecoder().decode(SubsonicWrapper<LyricsPayload>.self, from: data)
            
            if let rawText = wrapper.subsonicResponse.data?.lyrics?.value, !rawText.isEmpty {
                return await parseLRC(rawText)
            }
        } catch {
            // Ignore error
        }
        
        return (false, [])
    }
    
    private func fetchLyricsBySongId(songId: String) async -> (synced: Bool, lines: [(time: TimeInterval, text: String)])? {
        do {
            let params = [URLQueryItem(name: "id", value: songId)]
            let url = try buildURL(endpoint: "getLyricsBySongId.view", additionalParams: params)
            let (data, _) = try await session.data(from: url)
            let wrapper = try JSONDecoder().decode(SubsonicWrapper<LyricsPayload>.self, from: data)
            
            if let structured = wrapper.subsonicResponse.data?.lyricsList?.structuredLyrics?.first {
                let synced = structured.synced ?? false
                let offsetSec = TimeInterval(structured.offset ?? 0) / 1000.0
                var lines: [(time: TimeInterval, text: String)] = []
                for l in structured.line ?? [] {
                    let sec = max(0, TimeInterval(l.start ?? 0) / 1000.0 - offsetSec)
                    lines.append((time: sec, text: l.value ?? ""))
                }
                lines.sort { $0.time < $1.time }
                return (synced, lines)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func parseLRC(_ text: String) async -> (synced: Bool, lines: [(time: TimeInterval, text: String)]) {
        let (synced, parsedLines) = await MainActor.run {
            LyricsService.shared.parseLRC(text)
        }
        return (synced, parsedLines.map { (time: $0.time, text: $0.text) })
    }
    
    public func setStarred(id: String, star: Bool) async throws {
        let endpoint = star ? "star.view" : "unstar.view"
        let params = [URLQueryItem(name: "id", value: id)]
        let url = try buildURL(endpoint: endpoint, additionalParams: params)
        let _ = try await session.data(from: url)
    }
}
