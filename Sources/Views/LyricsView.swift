import SwiftUI

public struct LyricsView: View {
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init() {}
    
    private var isLightMode: Bool {
        themeManager.currentTheme == .light
    }
    
    public var body: some View {
        ZStack {
            // Adaptive ambient background (Light / Dark)
            ambientBackground
            
            VStack(spacing: 0) {
                // Top header bar
                headerBar
                
                // Lyrics Content
                if player.lyrics.isEmpty {
                    emptyLyricsView
                } else {
                    lyricsScrollView
                }
            }
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            if let track = player.currentTrack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isLightMode ? .primary : .white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(isLightMode ? .secondary : .white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Lyric timing offset calibration controls (if synced)
            if player.isLyricsSynced {
                HStack(spacing: 4) {
                    Button(action: { player.adjustLyricOffset(by: -0.2) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("歌词延后 0.2 秒（歌词太快时使用）")
                    
                    Button(action: { player.resetLyricOffset() }) {
                        Text(offsetLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .help("点击重置歌词时间微调")
                    
                    Button(action: { player.adjustLyricOffset(by: 0.2) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("歌词提前 0.2 秒（歌词偏慢时使用）")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.12))
                .foregroundColor(isLightMode ? .primary.opacity(0.8) : .white.opacity(0.85))
                .cornerRadius(8)
            }
            
            // KTV Mode badge
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 10))
                Text("KTV 逐字伴唱")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appleMusicRed.opacity(isLightMode ? 0.15 : 0.25))
            .foregroundColor(appleMusicRed)
            .cornerRadius(10)
            
            Button(action: { player.showLyrics = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isLightMode ? Color.secondary.opacity(0.7) : Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("关闭歌词")
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var offsetLabel: String {
        let val = player.lyricOffset
        if abs(val) < 0.05 {
            return "同步 0.0s"
        } else if val > 0 {
            return String(format: "提前 +%.1fs", val)
        } else {
            return String(format: "延后 %.1fs", val)
        }
    }
    
    private var emptyLyricsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 44))
                .foregroundColor(isLightMode ? .secondary.opacity(0.4) : .white.opacity(0.4))
            Text("暂无歌词")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isLightMode ? .secondary : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var lyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                TimelineView(.animation(paused: !player.isPlaying)) { _ in
                    let currentTime = player.effectivePlaybackTime()
                    let currentIdx = player.currentLyricIndex ?? -1
                    
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 80)
                        
                        ForEach(Array(player.lyrics.enumerated()), id: \.element.id) { index, line in
                            let isCurrent = currentIdx == index
                            let isPast = currentIdx > index
                            let progress = calculateProgress(for: index, currentTime: currentTime, currentIndex: currentIdx)
                            
                            KTVLyricLineView(
                                line: line,
                                isCurrent: isCurrent,
                                isPast: isPast,
                                progress: progress,
                                isLightMode: isLightMode,
                                onSeek: {
                                    if player.isLyricsSynced {
                                        player.seek(to: line.time)
                                    }
                                }
                            )
                            .id(index)
                        }
                        
                        Spacer().frame(height: 140)
                    }
                    .padding(.horizontal, 36)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: player.currentLyricIndex) { _, newIndex in
                if let targetIndex = newIndex {
                    withAnimation(.easeOut(duration: 0.28)) {
                        proxy.scrollTo(targetIndex, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func calculateProgress(for index: Int, currentTime: TimeInterval, currentIndex: Int) -> Double {
        if index < currentIndex {
            return 1.0
        } else if index > currentIndex {
            return 0.0
        }
        
        let line = player.lyrics[index]
        let startTime = line.time
        let nextLineTime: TimeInterval
        if index + 1 < player.lyrics.count {
            nextLineTime = player.lyrics[index + 1].time
        } else {
            nextLineTime = max(startTime + 4.0, player.duration)
        }
        
        // 1. If enhanced LRC per-word timestamps exist, interpolate precisely across words
        if let words = line.words, !words.isEmpty {
            let totalChars = max(1, words.reduce(0) { $0 + max(1, $1.text.count) })
            if currentTime <= words[0].time {
                return 0.0
            }
            var accumulatedChars = 0
            for (wIdx, word) in words.enumerated() {
                let wChars = max(1, word.text.count)
                let wStart = word.time
                let wEnd: TimeInterval
                if wIdx + 1 < words.count {
                    wEnd = max(wStart + 0.05, words[wIdx + 1].time)
                } else {
                    let estEnd = wStart + max(0.35, Double(wChars) * 0.28)
                    wEnd = min(nextLineTime, max(wStart + 0.1, estEnd))
                }
                
                if currentTime < wEnd {
                    let wordFrac = min(max((currentTime - wStart) / max(wEnd - wStart, 0.05), 0.0), 1.0)
                    let pos = (Double(accumulatedChars) + wordFrac * Double(wChars)) / Double(totalChars)
                    return min(max(pos, 0.0), 1.0)
                }
                accumulatedChars += wChars
            }
            return 1.0
        }
        
        // 2. Standard line-level LRC: estimate vocal duration so highlight finishes with the voice
        // instead of dragging across trailing breaths or instrumental interludes.
        let rawGap = max(nextLineTime - startTime, 0.35)
        let vocalUnits = estimatedVocalUnits(for: line.text)
        let estimatedSingDuration = max(1.0, vocalUnits * 0.36)
        
        let effectiveSingDuration: TimeInterval
        if rawGap <= 6.0 {
            // Normal lyrical phrasing: finish ~12% before next line starts, or at estimated vocal pace
            effectiveSingDuration = min(rawGap * 0.88, max(rawGap * 0.65, estimatedSingDuration))
        } else {
            // Long instrumental gap after this line: don't stretch the wipe across the whole interlude
            effectiveSingDuration = min(rawGap * 0.85, max(2.0, estimatedSingDuration * 1.15))
        }
        
        let elapsed = max(0, currentTime - startTime)
        return min(max(elapsed / max(effectiveSingDuration, 0.3), 0.0), 1.0)
    }
    
    private func estimatedVocalUnits(for text: String) -> Double {
        var units = 0.0
        var inAsciiWord = false
        var asciiChars = 0
        
        for scalar in text.unicodeScalars {
            let v = scalar.value
            let isCJK = (0x4E00...0x9FFF).contains(v) || (0x3040...0x30FF).contains(v) || (0xAC00...0xD7AF).contains(v)
            if isCJK {
                if inAsciiWord {
                    units += max(1.0, Double(asciiChars) / 4.0)
                    inAsciiWord = false
                    asciiChars = 0
                }
                units += 1.0
            } else if CharacterSet.alphanumerics.contains(scalar) {
                inAsciiWord = true
                asciiChars += 1
            } else {
                if inAsciiWord {
                    units += max(1.0, Double(asciiChars) / 4.0)
                    inAsciiWord = false
                    asciiChars = 0
                }
            }
        }
        if inAsciiWord {
            units += max(1.0, Double(asciiChars) / 4.0)
        }
        return max(1.0, units)
    }
    
    private var ambientBackground: some View {
        ZStack {
            if isLightMode {
                // Light Mode: Clean pearlescent background with soft pastel watercolor washes
                Color(NSColor.windowBackgroundColor)
                
                Circle()
                    .fill(appleMusicRed.opacity(0.16))
                    .frame(width: 500, height: 500)
                    .offset(x: -120, y: -90)
                    .blur(radius: 95)
                
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 440, height: 440)
                    .offset(x: 140, y: 110)
                    .blur(radius: 100)
                
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 380, height: 380)
                    .offset(x: -80, y: 160)
                    .blur(radius: 90)
            } else {
                // Dark Mode: Deep vibrant blur on dark background
                Color.black
                
                Circle()
                    .fill(appleMusicRed.opacity(0.45))
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -80)
                    .blur(radius: 90)
                
                Circle()
                    .fill(Color.purple.opacity(0.4))
                    .frame(width: 350, height: 350)
                    .offset(x: 120, y: 100)
                    .blur(radius: 90)
                
                Circle()
                    .fill(Color.blue.opacity(0.35))
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: 150)
                    .blur(radius: 80)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - KTV Lyric Line View (逐字平滑点亮)
private struct KTVLyricLineView: View {
    let line: LyricLineItem
    let isCurrent: Bool
    let isPast: Bool
    let progress: Double // 0.0 ~ 1.0
    let isLightMode: Bool
    let onSeek: () -> Void
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    var body: some View {
        Button(action: onSeek) {
            ZStack(alignment: .leading) {
                // Base unlit text layer
                Text(line.text)
                    .font(.system(size: isCurrent ? 26 : 21, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundColor(baseTextColor)
                
                // Highlighted text layer (progressively revealed from left to right, line-by-line if wrapped)
                if isCurrent {
                    Text(line.text)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(activeTextColor)
                        .shadow(color: isLightMode ? appleMusicRed.opacity(0.3) : Color.white.opacity(0.5), radius: 6, x: 0, y: 0)
                        .mask(
                            GeometryReader { geo in
                                let lineCount = max(1, Int((geo.size.height / 34.0).rounded()))
                                let rowHeight = geo.size.height / CGFloat(lineCount)
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(0..<lineCount, id: \.self) { row in
                                        let rowStart = Double(row) / Double(lineCount)
                                        let rowEnd = Double(row + 1) / Double(lineCount)
                                        let rowProgress = min(max((progress - rowStart) / (rowEnd - rowStart), 0.0), 1.0)
                                        Rectangle()
                                            .frame(width: geo.size.width * CGFloat(rowProgress), height: rowHeight)
                                    }
                                }
                            }
                        )
                }
            }
            .scaleEffect(isCurrent ? 1.04 : 1.0, anchor: .leading)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isCurrent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var baseTextColor: Color {
        if isCurrent {
            return isLightMode ? Color.primary.opacity(0.3) : Color.white.opacity(0.35)
        } else if isPast {
            return isLightMode ? Color.primary.opacity(0.42) : Color.white.opacity(0.5)
        } else {
            return isLightMode ? Color.primary.opacity(0.25) : Color.white.opacity(0.25)
        }
    }
    
    private var activeTextColor: Color {
        if isLightMode {
            return appleMusicRed // Vibrant Apple Music signature red for light KTV
        } else {
            return .white // Radiant white with soft glow for dark KTV
        }
    }
}
