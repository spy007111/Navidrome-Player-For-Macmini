import SwiftUI

public struct SongsTableView: View {
    public let title: String
    public let tracks: [Track]
    
    @ObservedObject var player = PlayerManager.shared
    @UIState private var searchText: String = ""
    @UIState private var hoveredTrackId: String? = nil
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(title: String = "歌曲", tracks: [Track]) {
        self.title = title
        self.tracks = tracks
    }
    
    private var filteredTracks: [Track] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return tracks
        }
        let q = searchText.lowercased()
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                
                Spacer()
                
                // Search filter bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("过滤歌曲...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: 200)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 14)
            
            // Table Header
            HStack(spacing: 12) {
                Text("#")
                    .frame(width: 30, alignment: .center)
                Text("标题")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("艺人")
                    .frame(width: 160, alignment: .leading)
                Text("专辑")
                    .frame(width: 180, alignment: .leading)
                Text("时长")
                    .frame(width: 60, alignment: .trailing)
                Text("")
                    .frame(width: 40)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
            
            Divider()
            
            // Song Rows
            if filteredTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无歌曲")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                            songRow(index: index, track: track)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func songRow(index: Int, track: Track) -> some View {
        let isCurrent = player.currentTrack?.id == track.id
        let isHovered = hoveredTrackId == track.id
        
        return HStack(spacing: 12) {
            // Index or Play Icon
            Group {
                if isCurrent && player.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(appleMusicRed)
                } else if isHovered {
                    Button(action: { player.playTrack(track, in: filteredTracks) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 30, alignment: .center)
            
            // Artwork & Title
            HStack(spacing: 8) {
                AsyncCoverImage(
                    localData: track.localCoverData,
                    coverArtPath: track.coverArtPath,
                    urlString: track.coverArtURLString,
                    cornerRadius: 3
                )
                .frame(width: 30, height: 30)
                
                Text(track.title)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? appleMusicRed : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Artist
            Text(track.artist)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
            
            // Album
            Text(track.album)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)
            
            // Duration
            Text(track.formattedDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            // Actions
            HStack(spacing: 6) {
                if track.source.isLocal {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                        .help("本地文件")
                } else {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 10))
                        .foregroundColor(appleMusicRed.opacity(0.8))
                        .help("Navidrome")
                }
                
                Menu {
                    Button("立即播放") { player.playTrack(track, in: filteredTracks) }
                    Button("下一首播放") { player.playNext(track) }
                    Button("添加到待播清单") { player.addToQueue(track) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .menuStyle(.borderlessButton)
                .opacity(isHovered ? 1.0 : 0.0)
            }
            .frame(width: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.06) : (index % 2 == 1 ? Color.primary.opacity(0.015) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTrackId = hovering ? track.id : nil
        }
        .onTapGesture(count: 2) {
            player.playTrack(track, in: filteredTracks)
        }
        .contextMenu {
            Button("播放") { player.playTrack(track, in: filteredTracks) }
            Button("下一首播放") { player.playNext(track) }
            Button("添加到待播清单") { player.addToQueue(track) }
        }
    }
}
