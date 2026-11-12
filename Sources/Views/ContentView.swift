import SwiftUI

public struct ContentView: View {
    @UIState private var selectedSection: NavigationSection? = .listenNow
    @UIState private var selectedAlbum: Album? = nil
    
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var localManager = LocalLibraryManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Apple Music signature top playback bar
            PlayerBarView()
                .zIndex(10)
            
            // Main body: Navigation split view
            ZStack(alignment: .trailing) {
                NavigationSplitView {
                    SidebarView(selection: $selectedSection)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } detail: {
                    mainDetailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor))
                }
                
                // Slide-out Queue Panel
                if player.showQueue {
                    QueueView()
                        .transition(.move(edge: .trailing))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: -5, y: 0)
                        .zIndex(20)
                }
                
                // Fullscreen / Overlay Lyrics Sheet
                if player.showLyrics {
                    LyricsView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: player.showQueue)
        .animation(.easeInOut(duration: 0.25), value: player.showLyrics)
        .frame(minWidth: 960, minHeight: 640)
    }
    
    @ViewBuilder
    private var mainDetailContent: some View {
        if let album = selectedAlbum {
            AlbumDetailView(album: album) {
                selectedAlbum = nil
            }
        } else {
            switch selectedSection ?? .listenNow {
            case .listenNow:
                ListenNowView(
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            case .browse, .albums:
                AlbumsGridView(
                    title: selectedSection == .browse ? "浏览专辑" : "专辑",
                    albums: localManager.albums,
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            case .recentlyAdded:
                AlbumsGridView(
                    title: "最近添加",
                    albums: Array(localManager.albums.prefix(30)),
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            case .artists:
                LocalMusicView(
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            case .songs:
                SongsTableView(title: "歌曲", tracks: localManager.tracks)
            case .localMusic:
                LocalMusicView(
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            case .navidrome:
                NavidromeView(
                    onSelectAlbum: { selectedAlbum = $0 },
                    onPlayAlbum: playAlbumDirectly
                )
            }
        }
    }
    
    private func playAlbumDirectly(album: Album) {
        Task {
            if album.isNavidrome {
                if let (_, tracks) = try? await NavidromeClient.shared.getAlbumDetail(albumId: album.id),
                   let first = tracks.first {
                    player.playTrack(first, in: tracks)
                }
            } else {
                let tracks = localManager.tracks.filter {
                    $0.album == album.title && $0.artist == album.artist
                }.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
                if let first = tracks.first {
                    player.playTrack(first, in: tracks)
                }
            }
        }
    }
}
