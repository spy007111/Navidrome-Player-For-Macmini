import SwiftUI

public struct AlbumCardView: View {
    public let album: Album
    public var onSelect: () -> Void
    public var onPlay: () -> Void
    
    @UIState private var isHovering = false
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(album: Album, onSelect: @escaping () -> Void, onPlay: @escaping () -> Void) {
        self.album = album
        self.onSelect = onSelect
        self.onPlay = onPlay
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncCoverImage(
                    localData: album.localCoverData,
                    coverArtPath: album.coverArtPath,
                    urlString: album.coverArtURLString,
                    cornerRadius: 8
                )
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(isHovering ? 0.25 : 0.12), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
                
                // Hover play button
                if isHovering {
                    Button(action: onPlay) {
                        ZStack {
                            Circle()
                                .fill(appleMusicRed)
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(album.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if album.isNavidrome {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 9))
                            .foregroundColor(appleMusicRed.opacity(0.8))
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
    }
}

public struct AlbumsGridView: View {
    public let title: String
    public let albums: [Album]
    public var onSelectAlbum: (Album) -> Void
    public var onPlayAlbum: (Album) -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]
    
    public init(
        title: String = "专辑",
        albums: [Album],
        onSelectAlbum: @escaping (Album) -> Void,
        onPlayAlbum: @escaping (Album) -> Void
    ) {
        self.title = title
        self.albums = albums
        self.onSelectAlbum = onSelectAlbum
        self.onPlayAlbum = onPlayAlbum
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                    Spacer()
                    Text("\(albums.count) 张专辑")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                
                if albums.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无专辑")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            AlbumCardView(
                                album: album,
                                onSelect: { onSelectAlbum(album) },
                                onPlay: { onPlayAlbum(album) }
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}
