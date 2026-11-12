import SwiftUI

public struct QueueView: View {
    @ObservedObject var player = PlayerManager.shared
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("待播清单")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                if player.queue.count > 1 {
                    Button("清除") {
                        player.clearQueue()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundColor(appleMusicRed)
                }
                
                Button(action: { player.showQueue = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // Queue list
            if player.queue.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("待播清单为空")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Currently Playing section
                        if let current = player.currentTrack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("正在播放")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                queueRow(track: current, isPlaying: true, index: player.queueIndex)
                            }
                        }
                        
                        // Up Next section
                        let upNextList = Array(player.queue.enumerated()).filter { $0.offset > player.queueIndex }
                        if !upNextList.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("接下来播放 (\(upNextList.count))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                ForEach(upNextList, id: \.element.id) { index, track in
                                    queueRow(track: track, isPlaying: false, index: index)
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
    
    private func queueRow(track: Track, isPlaying: Bool, index: Int) -> some View {
        HStack(spacing: 10) {
            AsyncCoverImage(
                localData: track.localCoverData,
                coverArtPath: track.coverArtPath,
                urlString: track.coverArtURLString,
                cornerRadius: 4
            )
            .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: isPlaying ? .bold : .regular))
                    .foregroundColor(isPlaying ? appleMusicRed : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(appleMusicRed)
            } else {
                Button(action: { player.removeQueueItem(at: index) }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPlaying ? appleMusicRed.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPlaying {
                player.playTrack(track, in: player.queue)
            }
        }
    }
}
