import Foundation

public struct SubsonicWrapper<T: Decodable>: Decodable {
    public let subsonicResponse: SubsonicResponse<T>
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

public struct SubsonicResponse<T: Decodable>: Decodable {
    public let status: String
    public let version: String?
    public let type: String?
    public let serverVersion: String?
    public let openSubsonic: Bool?
    public let error: SubsonicError?
    public let data: T?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        self.status = (try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "status")!)) ?? "failed"
        self.version = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "version")!)
        self.type = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "type")!)
        self.serverVersion = try? container.decode(String.self, forKey: DynamicCodingKey(stringValue: "serverVersion")!)
        self.openSubsonic = try? container.decode(Bool.self, forKey: DynamicCodingKey(stringValue: "openSubsonic")!)
        self.error = try? container.decode(SubsonicError.self, forKey: DynamicCodingKey(stringValue: "error")!)
        
        // Attempt to decode the specific payload T from the root container
        self.data = try? T(from: decoder)
    }
}

public struct SubsonicError: Decodable, Error, LocalizedError, CustomNSError, @unchecked Sendable {
    public let code: Int
    public let message: String
    
    enum CodingKeys: String, CodingKey {
        case code, message
    }
    
    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intCode = try? container.decode(Int.self, forKey: .code) {
            self.code = intCode
        } else if let strCode = try? container.decode(String.self, forKey: .code), let parsed = Int(strCode) {
            self.code = parsed
        } else {
            self.code = -1
        }
        self.message = (try? container.decode(String.self, forKey: .message)) ?? "未知服务器错误"
    }
    
    public static var errorDomain: String {
        return "Subsonic"
    }
    
    public var errorCode: Int {
        return code
    }
    
    public var errorDescription: String? {
        return localizedErrorMessage
    }
    
    public var localizedErrorMessage: String {
        switch code {
        case 10:
            return "缺少必需的请求参数 (Code 10)"
        case 20:
            return "客户端 Subsonic API 版本不兼容 (Code 20)"
        case 30:
            return "服务器 Subsonic API 版本过低 (Code 30)"
        case 40:
            return "用户名或密码错误，请核对用户名和密码 (Code 40)"
        case 50:
            return "该用户无权访问此资源，请检查账号权限 (Code 50)"
        case 60:
            return "Subsonic 服务器试用期已结束 (Code 60)"
        case 70:
            return "未找到请求的数据 (Code 70)"
        case 401:
            return "HTTP 401: 认证未通过，请检查用户名和密码"
        case 403:
            return "HTTP 403: 访问被拒绝，可能存在反向代理拦截"
        case 404:
            return "HTTP 404: 未在指定地址找到 Navidrome API (/rest/ping.view)，请检查地址是否正确"
        case 502:
            return "HTTP 502: 网关错误，Navidrome 后端服务可能未正常启动"
        case 503, 504:
            return "HTTP \(code): 网关超时或服务不可用，请检查服务端状态"
        default:
            return message.isEmpty ? "服务器错误 (Code \(code))" : "\(message) (Code \(code))"
        }
    }
}

public struct EmptyPayload: Decodable {}

public struct RandomSongsPayload: Decodable {
    public let randomSongs: RandomSongsContainer?
    
    public struct RandomSongsContainer: Decodable {
        public let song: [SubsonicSongItem]?
    }
}

public struct AlbumListPayload: Decodable {
    public let albumList2: AlbumListContainer?
    
    public struct AlbumListContainer: Decodable {
        public let album: [SubsonicAlbumItem]?
    }
}

public struct SubsonicAlbumItem: Decodable {
    public let id: String
    public let name: String?
    public let title: String?
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let songCount: Int?
    public let duration: Int?
    public let year: Int?
    public let genre: String?
    
    public var displayTitle: String {
        return title ?? name ?? "未知专辑"
    }
}

public struct AlbumDetailPayload: Decodable {
    public let album: AlbumDetailContainer?
    
    public struct AlbumDetailContainer: Decodable {
        public let id: String
        public let name: String?
        public let title: String?
        public let artist: String?
        public let coverArt: String?
        public let year: Int?
        public let genre: String?
        public let songCount: Int?
        public let duration: Int?
        public let song: [SubsonicSongItem]?
    }
}

public struct SubsonicSongItem: Decodable {
    public let id: String
    public let title: String
    public let album: String?
    public let artist: String?
    public let track: Int?
    public let discNumber: Int?
    public let year: Int?
    public let genre: String?
    public let coverArt: String?
    public let size: Int64?
    public let contentType: String?
    public let suffix: String?
    public let duration: Int?
    public let bitRate: Int?
    public let starred: String?
    
    public var isStarred: Bool {
        return starred != nil
    }
}

public struct ArtistsPayload: Decodable {
    public let artists: ArtistsContainer?
    
    public struct ArtistsContainer: Decodable {
        public let index: [ArtistIndexItem]?
    }
    
    public struct ArtistIndexItem: Decodable {
        public let name: String
        public let artist: [SubsonicArtistItem]?
    }
}

public struct SubsonicArtistItem: Decodable {
    public let id: String
    public let name: String
    public let albumCount: Int?
    public let coverArt: String?
}

public struct ArtistDetailPayload: Decodable {
    public let artist: ArtistDetailContainer?
    
    public struct ArtistDetailContainer: Decodable {
        public let id: String
        public let name: String
        public let coverArt: String?
        public let album: [SubsonicAlbumItem]?
    }
}

public struct SearchPayload: Decodable {
    public let searchResult3: SearchResultContainer?
    
    public struct SearchResultContainer: Decodable {
        public let song: [SubsonicSongItem]?
        public let album: [SubsonicAlbumItem]?
        public let artist: [SubsonicArtistItem]?
    }
}

public struct LyricsPayload: Decodable {
    public let lyrics: LyricsContainer?
    public let lyricsList: StructuredLyricsContainer?
    
    public struct LyricsContainer: Decodable {
        public let artist: String?
        public let title: String?
        public let value: String?
    }
    
    public struct StructuredLyricsContainer: Decodable {
        public let structuredLyrics: [StructuredLyric]?
    }
    
    public struct StructuredLyric: Decodable {
        public let synced: Bool?
        public let offset: Int? // milliseconds offset from LRC [offset:] tag
        public let line: [LyricLine]?
    }
    
    public struct LyricLine: Decodable {
        public let start: Int? // in milliseconds
        public let value: String?
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
