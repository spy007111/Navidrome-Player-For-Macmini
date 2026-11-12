import SwiftUI

public struct PlayerBarView: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @UIState private var isDraggingScrubber = false
    @UIState private var dragScrubTime: TimeInterval = 0
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 16) {
            // Left: Playback controls
            playbackControls
                .frame(minWidth: 220, alignment: .leading)
            
            Spacer()
            
            // Center: Signature Apple Music LCD Display Pill
            nowPlayingDisplay
                .frame(maxWidth: 480)
            
            Spacer()
            
            // Right: Volume & Extra toggles (Lyrics, Queue)
            rightControls
                .frame(minWidth: 240, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Divider()
                .opacity(0.4),
            alignment: .bottom
        )
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 14) {
            // Shuffle
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(player.isShuffled ? appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help("随机播放")
            
            // Previous
            Button(action: { player.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("上一首")
            
            // Play / Pause
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help(player.isPlaying ? "暂停" : "播放")
            
            // Next
            Button(action: { player.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .help("下一首")
            
            // Repeat
            Button(action: { player.toggleRepeat() }) {
                Image(systemName: player.repeatMode.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(player.repeatMode != .off ? appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help(repeatHelpText)
        }
    }
    
    private var repeatHelpText: String {
        switch player.repeatMode {
        case .off: return "列表播放"
        case .all: return "全部循环"
        case .one: return "单曲循环"
        }
    }
    
    // MARK: - Center Now Playing LCD Box
    private var nowPlayingDisplay: some View {
        HStack(spacing: 10) {
            if let track = player.currentTrack {
                // Artwork thumbnail
                AsyncCoverImage(
                    localData: track.localCoverData,
                    coverArtPath: track.coverArtPath,
                    urlString: track.coverArtURLString,
                    cornerRadius: 4
                )
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                
                // Track Info & Scrubber
                VStack(spacing: 3) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Text(track.artist)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Text("—")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text(track.album)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Source indicator badge
                        if track.source.isLocal {
                            Image(systemName: "laptopcomputer")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .help("本地音乐")
                        } else {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 9))
                                .foregroundColor(appleMusicRed)
                                .help("Navidrome 云端音乐")
                        }
                    }
                    
                    // Scrubber Bar
                    scrubberBar
                }
            } else {
                // Empty state Apple Music logo
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundColor(appleMusicRed)
                    Text("Apple Music")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - Scrubber Bar
    private var scrubberBar: some View {
        let displayCurrent = isDraggingScrubber ? dragScrubTime : player.currentTime
        let maxDuration = max(player.duration, 1.0)
        let progress = min(max(displayCurrent / maxDuration, 0.0), 1.0)
        let remaining = max(maxDuration - displayCurrent, 0)
        
        return HStack(spacing: 6) {
            Text(formatTime(displayCurrent))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 32, alignment: .trailing)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    
                    // Progress fill
                    Capsule()
                        .fill(Color.primary.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(progress), height: 3)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingScrubber = true
                            let ratio = max(0, min(value.location.x / geo.size.width, 1))
                            dragScrubTime = ratio * maxDuration
                        }
                        .onEnded { value in
                            let ratio = max(0, min(value.location.x / geo.size.width, 1))
                            let targetTime = ratio * maxDuration
                            player.seek(to: targetTime)
                            isDraggingScrubber = false
                        }
                )
            }
            .frame(height: 10)
            
            Text("-" + formatTime(remaining))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
    
    // MARK: - Right Controls
    private var rightControls: some View {
        HStack(spacing: 14) {
            // Volume control
            HStack(spacing: 6) {
                Button(action: { player.toggleMute() }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 12))
                        .foregroundColor(player.isMuted ? appleMusicRed : .secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                
                Slider(
                    value: Binding(
                        get: { Double(player.volume) },
                        set: {
                            player.volume = Float($0)
                            if player.isMuted { player.isMuted = false }
                        }
                    ),
                    in: 0...1
                )
                .frame(width: 80)
                .accentColor(appleMusicRed)
            }
            
            Divider()
                .frame(height: 16)
            
            // Theme toggle button
            Button(action: { ThemeManager.shared.toggleLightDark() }) {
                Image(systemName: ThemeManager.shared.currentTheme == .light ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(ThemeManager.shared.currentTheme == .light ? "切换到深色外观" : "切换到浅色外观 (白色)")
            
            // Lyrics button
            Button(action: { player.showLyrics.toggle() }) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundColor(player.showLyrics ? appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help("实时歌词")
            
            // Queue button
            Button(action: { player.showQueue.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundColor(player.showQueue ? appleMusicRed : .secondary)
            }
            .buttonStyle(.plain)
            .help("待播清单")
        }
    }
    
    private var volumeIcon: String {
        if player.isMuted || player.volume == 0 {
            return "speaker.slash.fill"
        } else if player.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if player.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
