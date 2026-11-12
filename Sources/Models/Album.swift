import Foundation

public struct Album: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var artist: String
    public var year: Int?
    public var genre: String?
    public var songCount: Int
    public var duration: TimeInterval
    public var coverArtURLString: String?
    public var localCoverData: Data?
    public var coverArtPath: String?
    public var isNavidrome: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "未知艺人",
        year: Int? = nil,
        genre: String? = nil,
        songCount: Int = 0,
        duration: TimeInterval = 0,
        coverArtURLString: String? = nil,
        localCoverData: Data? = nil,
        coverArtPath: String? = nil,
        isNavidrome: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.genre = genre
        self.songCount = songCount
        self.duration = duration
        self.coverArtURLString = coverArtURLString
        self.localCoverData = localCoverData
        self.coverArtPath = coverArtPath
        self.isNavidrome = isNavidrome
    }
}

public struct Artist: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var albumCount: Int
    public var isNavidrome: Bool
    public var coverArtURLString: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        albumCount: Int = 0,
        isNavidrome: Bool = false,
        coverArtURLString: String? = nil
    ) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.isNavidrome = isNavidrome
        self.coverArtURLString = coverArtURLString
    }
}
