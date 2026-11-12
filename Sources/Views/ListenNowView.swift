import SwiftUI

public struct ListenNowView: View {
    public var onSelectAlbum: (Album) -> Void
    public var onPlayAlbum: (Album) -> Void
    
    @ObservedObject var localManager = LocalLibraryManager.shared
    @ObservedObject var player = PlayerManager.shared
    @UIState private var navidromeAlbums: [Album] = []
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(onSelectAlbum: @escaping (Album) -> Void, onPlayAlbum: @escaping (Album) -> Void) {
        self.onSelectAlbum = onSelectAlbum
        self.onPlayAlbum = onPlayAlbum
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Large Page Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("现在就听")
                        .font(.system(size: 28, weight: .bold))
                    Text("为你量身打造的精选音乐")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                
                // Featured Hero Banner
                featuredHeroCard
                    .padding(.horizontal, 28)
                
                // Section: Recently Added Local Music
                if !localManager.albums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("本地珍藏专辑")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                            Text("共 \(localManager.albums.count) 张")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(localManager.albums.prefix(10)) { album in
                                    AlbumCardView(
                                        album: album,
                                        onSelect: { onSelectAlbum(album) },
                                        onPlay: { onPlayAlbum(album) }
                                    )
                                    .frame(width: 160)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
                
                // Section: Navidrome Server Recent Albums
                if !navidromeAlbums.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Text("来自 Navidrome 云端")
                                    .font(.system(size: 18, weight: .bold))
                                Image(systemName: "cloud.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(appleMusicRed)
                            }
                            Spacer()
                            Text("最新同步")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(navidromeAlbums.prefix(10)) { album in
                                    AlbumCardView(
                                        album: album,
                                        onSelect: { onSelectAlbum(album) },
                                        onPlay: { onPlayAlbum(album) }
                                    )
                                    .frame(width: 160)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .task {
            await loadNavidromeAlbums()
        }
    }
    
    private var featuredHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.pink.opacity(0.8), Color.orange.opacity(0.7), appleMusicRed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("私人精选漫游")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .textCase(.uppercase)
                
                Text("开始今日畅听之旅")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("融合本地与 Navidrome 收藏，尽享无缝高保真音质")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 12) {
                    Button(action: startDiscoveryPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("随机开始")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }
    
    private func loadNavidromeAlbums() async {
        do {
            self.navidromeAlbums = try await NavidromeClient.shared.getAlbums(type: "recent", size: 12)
        } catch {
            // Not connected yet or failed
        }
    }
    
    private func startDiscoveryPlay() {
        let pool: [Track] = localManager.tracks
        if pool.isEmpty {
            // If local is empty, try first navidrome album
            if let first = navidromeAlbums.first {
                onPlayAlbum(first)
            }
            return
        }
        let shuffled = pool.shuffled()
        if let first = shuffled.first {
            player.playTrack(first, in: shuffled)
        }
    }
}
