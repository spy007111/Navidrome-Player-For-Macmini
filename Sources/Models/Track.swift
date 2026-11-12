import Foundation
import AppKit

public enum TrackSource: Codable, Equatable, Hashable {
    case local(path: String)
    case navidrome(id: String, streamURL: String)
    
    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }
}

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var source: TrackSource
    public var coverArtURLString: String?
    public var localCoverData: Data?
    public var coverArtPath: String?
    public var bitRate: Int?
    public var format: String?
    public var isFavorite: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "未知艺人",
        album: String = "未知专辑",
        duration: TimeInterval = 0,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        source: TrackSource,
        coverArtURLString: String? = nil,
        localCoverData: Data? = nil,
        coverArtPath: String? = nil,
        bitRate: Int? = nil,
        format: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.source = source
        self.coverArtURLString = coverArtURLString
        self.localCoverData = localCoverData
        self.coverArtPath = coverArtPath
        self.bitRate = bitRate
        self.format = format
        self.isFavorite = isFavorite
    }
    
    public var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var playbackURL: URL? {
        switch source {
        case .local(let path):
            return URL(fileURLWithPath: path)
        case .navidrome(_, let streamURL):
            return URL(string: streamURL)
        }
    }
}
