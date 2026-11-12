import SwiftUI

public struct AlbumDetailView: View {
    public let album: Album
    public var onBack: () -> Void
    
    @ObservedObject var player = PlayerManager.shared
    @UIState private var tracks: [Track] = []
    @UIState private var isLoading: Bool = false
    @UIState private var hoveredTrackId: String? = nil
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(album: Album, onBack: @escaping () -> Void) {
        self.album = album
        self.onBack = onBack
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Back Button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(appleMusicRed)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                
                // Album Header
                HStack(alignment: .bottom, spacing: 28) {
                    AsyncCoverImage(
                        localData: album.localCoverData,
                        coverArtPath: album.coverArtPath,
                        urlString: album.coverArtURLString,
                        cornerRadius: 10
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(album.title)
                            .font(.system(size: 26, weight: .bold))
                            .lineLimit(2)
                        
                        Text(album.artist)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(appleMusicRed)
                        
                        HStack(spacing: 6) {
                            if let genre = album.genre, !genre.isEmpty {
                                Text(genre)
                                Text("•")
                            }
                            if let year = album.year, year > 0 {
                                Text(String(year))
                                Text("•")
                            }
                            Text("\(tracks.count) 首歌曲")
                            Text("•")
                            Text(totalDurationString)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        
                        // Play / Shuffle Buttons
                        HStack(spacing: 12) {
                            Button(action: playAll) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13))
                                    Text("播放")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(appleMusicRed)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: shuffleAll) {
                                HStack(spacing: 6) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 13))
                                    Text("随机播放")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 6)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Tracklist Table
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("正在加载曲目...")
                        Spacer()
                    }
                    .padding(40)
                } else if tracks.isEmpty {
                    Text("暂无曲目")
                        .foregroundColor(.secondary)
                        .padding(20)
                } else {
                    trackListView
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .task {
            await loadTracks()
        }
    }
    
    private var trackListView: some View {
        VStack(spacing: 2) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let isCurrent = player.currentTrack?.id == track.id
                let isHovered = hoveredTrackId == track.id
                
                HStack(spacing: 12) {
                    // Track number or playing icon
                    Group {
                        if isCurrent && player.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(appleMusicRed)
                        } else if isHovered {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                        } else {
                            Text("\(track.trackNumber ?? (index + 1))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 26, alignment: .center)
                    
                    // Title
                    Text(track.title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .foregroundColor(isCurrent ? appleMusicRed : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Duration
                    Text(track.formattedDuration)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                    
                    // Quick menu
                    Menu {
                        Button("立即播放") {
                            player.playTrack(track, in: tracks)
                        }
                        Button("下一首播放") {
                            player.playNext(track)
                        }
                        Button("添加到播放队列") {
                            player.addToQueue(track)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .opacity(isHovered ? 1.0 : 0.0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    hoveredTrackId = hovering ? track.id : nil
                }
                .onTapGesture(count: 2) {
                    player.playTrack(track, in: tracks)
                }
                .contextMenu {
                    Button("播放") { player.playTrack(track, in: tracks) }
                    Button("下一首播放") { player.playNext(track) }
                    Button("添加到待播清单") { player.addToQueue(track) }
                }
            }
        }
    }
    
    private var totalDurationString: String {
        let total = tracks.reduce(0.0) { $0 + $1.duration }
        let mins = Int(total) / 60
        if mins > 60 {
            let hrs = mins / 60
            let remainMins = mins % 60
            return "\(hrs) 小时 \(remainMins) 分钟"
        } else {
            return "\(mins) 分钟"
        }
    }
    
    private func loadTracks() async {
        if album.isNavidrome {
            isLoading = true
            do {
                let (_, navTracks) = try await NavidromeClient.shared.getAlbumDetail(albumId: album.id)
                self.tracks = navTracks
            } catch {
                print("Failed to load navidrome album tracks: \(error)")
            }
            isLoading = false
        } else {
            // Local album: filter from LocalLibraryManager
            self.tracks = LocalLibraryManager.shared.tracks.filter {
                $0.album == album.title && $0.artist == album.artist
            }.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
        }
    }
    
    private func playAll() {
        guard let first = tracks.first else { return }
        player.playTrack(first, in: tracks)
    }
    
    private func shuffleAll() {
        guard !tracks.isEmpty else { return }
        let shuffled = tracks.shuffled()
        if let first = shuffled.first {
            player.playTrack(first, in: shuffled)
        }
    }
}
