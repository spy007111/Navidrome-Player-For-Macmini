import Foundation
import AVFoundation
import MediaPlayer
import AppKit

public enum RepeatMode: Int, CaseIterable, Codable {
    case off = 0
    case all = 1
    case one = 2
    
    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

@MainActor
public class PlayerManager: ObservableObject {
    public static let shared = PlayerManager()
    
    // Playback state
    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    @Published public var duration: TimeInterval = 0.0
    @Published public var volume: Float = 0.8 {
        didSet {
            player.volume = isMuted ? 0 : volume
            UserDefaults.standard.set(volume, forKey: "AppleMusicPlayer.Volume")
        }
    }
    @Published public var isMuted: Bool = false {
        didSet {
            player.volume = isMuted ? 0 : volume
        }
    }
    @Published public var repeatMode: RepeatMode = .off
    @Published public var isShuffled: Bool = false
    
    // Queue
    @Published public var queue: [Track] = []
    @Published public var queueIndex: Int = 0
    private var originalQueue: [Track] = []
    
    // Lyrics
    @Published public var lyrics: [LyricLineItem] = []
    @Published public var isLyricsSynced: Bool = false
    @Published public var currentLyricIndex: Int? = nil
    @Published public var lyricOffset: Double = 0.0 // Custom fine-tune offset in seconds (positive = lyrics appear earlier)
    
    // Smooth high-precision playback clock
    private var lastReportedPlaybackTime: TimeInterval = 0.0
    private var lastReportedHostTime: CFTimeInterval = CACurrentMediaTime()
    
    // UI state
    @Published public var showLyrics: Bool = false
    @Published public var showQueue: Bool = false
    
    private var player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var isSeeking: Bool = false
    
    private init() {
        if let savedVol = UserDefaults.standard.value(forKey: "AppleMusicPlayer.Volume") as? Float {
            self.volume = savedVol
        }
        if let savedOffset = UserDefaults.standard.value(forKey: "AppleMusicPlayer.LyricOffset") as? Double {
            self.lyricOffset = savedOffset
        }
        player.volume = self.volume
        
        setupTimeObserver()
        setupNotificationObservers()
        setupRemoteCommands()
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Playback Control
    
    public func playTrack(_ track: Track, in newQueue: [Track]? = nil) {
        if let customQueue = newQueue {
            self.originalQueue = customQueue
            if isShuffled {
                var shuffled = customQueue.filter { $0.id != track.id }.shuffled()
                shuffled.insert(track, at: 0)
                self.queue = shuffled
                self.queueIndex = 0
            } else {
                self.queue = customQueue
                self.queueIndex = customQueue.firstIndex(where: { $0.id == track.id }) ?? 0
            }
        } else {
            if !queue.contains(where: { $0.id == track.id }) {
                queue.append(track)
                queueIndex = queue.count - 1
            } else {
                queueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
            }
        }
        
        loadAndPlay(track: track)
    }
    
    private func loadAndPlay(track: Track) {
        self.currentTrack = track
        self.currentTime = 0
        self.lastReportedPlaybackTime = 0
        self.lastReportedHostTime = CACurrentMediaTime()
        self.duration = track.duration
        self.currentLyricIndex = nil
        
        // 1. If local track, play directly
        if track.source.isLocal {
            if let url = track.playbackURL {
                let playerItem = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: playerItem)
                player.play()
                self.isPlaying = true
            }
            updateNowPlayingInfo()
            loadLyrics(for: track)
            return
        }
        
        // 2. If Navidrome track is already cached locally, play cached file directly!
        if let cachedURL = AudioCacheManager.shared.cachedFileURL(for: track.id, format: track.format) {
            let playerItem = AVPlayerItem(url: cachedURL)
            player.replaceCurrentItem(with: playerItem)
            player.play()
            self.isPlaying = true
            updateNowPlayingInfo()
            loadLyrics(for: track)
            return
        }
        
        // 3. For new Navidrome track:
        guard let url = track.playbackURL else { return }
        
        // Attempt immediate playback with direct URL
        let directItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: directItem)
        player.play()
        self.isPlaying = true
        
        // In parallel, download via our TLS-safe session and automatically take over if direct playback is blocked
        Task { [weak self] in
            do {
                let fileURL = try await AudioCacheManager.shared.downloadTrack(track: track)
                guard let self = self, self.currentTrack?.id == track.id else { return }
                
                // If the player is stalled or didn't advance past 0.5s, switch to cached file
                if self.currentTime < 0.5 || self.player.timeControlStatus != .playing {
                    let fileItem = AVPlayerItem(url: fileURL)
                    self.player.replaceCurrentItem(with: fileItem)
                    self.player.play()
                    self.isPlaying = true
                }
            } catch {
                print("[PlayerManager] Background audio cache failed: \(error)")
            }
        }
        
        updateNowPlayingInfo()
        loadLyrics(for: track)
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func play() {
        if player.currentItem == nil, let track = currentTrack ?? queue.first {
            playTrack(track)
            return
        }
        lastReportedPlaybackTime = currentTime
        lastReportedHostTime = CACurrentMediaTime()
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    public func pause() {
        currentTime = effectivePlaybackTime(includeOffset: false)
        lastReportedPlaybackTime = currentTime
        lastReportedHostTime = CACurrentMediaTime()
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    public func next() {
        guard !queue.isEmpty else { return }
        
        if repeatMode == .one {
            seek(to: 0)
            player.play()
            isPlaying = true
            return
        }
        
        if queueIndex + 1 < queue.count {
            queueIndex += 1
            loadAndPlay(track: queue[queueIndex])
        } else if repeatMode == .all {
            queueIndex = 0
            loadAndPlay(track: queue[0])
        } else {
            pause()
            seek(to: 0)
        }
    }
    
    public func previous() {
        guard !queue.isEmpty else { return }
        
        // If elapsed > 3 seconds, replay current track
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        if queueIndex > 0 {
            queueIndex -= 1
            loadAndPlay(track: queue[queueIndex])
        } else if repeatMode == .all {
            queueIndex = queue.count - 1
            loadAndPlay(track: queue[queueIndex])
        } else {
            seek(to: 0)
        }
    }
    
    public func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration > 0 ? duration : time))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        currentTime = clamped
        lastReportedPlaybackTime = clamped
        lastReportedHostTime = CACurrentMediaTime()
        isSeeking = true
        updateLyricIndex(for: clamped)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSeeking = false
                self.lastReportedPlaybackTime = self.player.currentTime().seconds.isFinite ? self.player.currentTime().seconds : clamped
                self.lastReportedHostTime = CACurrentMediaTime()
                self.updateNowPlayingInfo()
                self.updateLyricIndex(for: self.lastReportedPlaybackTime)
            }
        }
    }
    
    public func toggleShuffle() {
        isShuffled.toggle()
        guard let current = currentTrack else { return }
        
        if isShuffled {
            var rest = queue.filter { $0.id != current.id }.shuffled()
            rest.insert(current, at: 0)
            self.queue = rest
            self.queueIndex = 0
        } else {
            if !originalQueue.isEmpty {
                self.queue = originalQueue
                self.queueIndex = originalQueue.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
    }
    
    public func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    public func toggleMute() {
        isMuted.toggle()
    }
    
    // MARK: - Queue Management
    
    public func addToQueue(_ track: Track) {
        queue.append(track)
    }
    
    public func playNext(_ track: Track) {
        if queue.isEmpty {
            playTrack(track)
        } else {
            queue.insert(track, at: min(queueIndex + 1, queue.count))
        }
    }
    
    public func clearQueue() {
        if let current = currentTrack {
            queue = [current]
            queueIndex = 0
        } else {
            queue.removeAll()
            queueIndex = 0
        }
    }
    
    public func removeQueueItem(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        if index == queueIndex {
            next()
        }
        queue.remove(at: index)
        if index < queueIndex {
            queueIndex -= 1
        }
    }
    
    // MARK: - Lyric Timing & High-Precision Playback Clock
    
    /// Returns the real-time playback position in seconds without 10Hz observer quantization lag.
    public func effectivePlaybackTime(includeOffset: Bool = true) -> TimeInterval {
        var baseTime = currentTime
        let playerSeconds = player.currentTime().seconds
        if playerSeconds.isFinite && !playerSeconds.isNaN && playerSeconds >= 0 && !isSeeking {
            baseTime = playerSeconds
        } else if isPlaying && !isSeeking {
            let dt = CACurrentMediaTime() - lastReportedHostTime
            if dt > 0 && dt < 1.0 {
                baseTime = lastReportedPlaybackTime + dt
            }
        }
        // Apply user-configured lyric offset plus 0.10s audio-buffer & perceptual lead
        let offset = includeOffset ? (lyricOffset + 0.10) : 0.0
        return max(0, baseTime + offset)
    }
    
    public func adjustLyricOffset(by delta: Double) {
        let raw = lyricOffset + delta
        let updated = (raw * 10.0).rounded() / 10.0
        lyricOffset = max(-5.0, min(5.0, updated))
        UserDefaults.standard.set(lyricOffset, forKey: "AppleMusicPlayer.LyricOffset")
        updateLyricIndex(for: effectivePlaybackTime(includeOffset: false))
    }
    
    public func resetLyricOffset() {
        lyricOffset = 0.0
        UserDefaults.standard.set(lyricOffset, forKey: "AppleMusicPlayer.LyricOffset")
        updateLyricIndex(for: effectivePlaybackTime(includeOffset: false))
    }
    
    // MARK: - Internal Observers
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self = self, !self.isSeeking else { return }
                let sec = CMTimeGetSeconds(time)
                if !sec.isNaN && !sec.isInfinite {
                    self.currentTime = sec
                    self.lastReportedPlaybackTime = sec
                    self.lastReportedHostTime = CACurrentMediaTime()
                    if let dur = self.player.currentItem?.duration.seconds, !dur.isNaN && !dur.isInfinite && dur > 0 {
                        self.duration = dur
                    }
                    self.updateLyricIndex(for: sec)
                }
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
        }
    }
    
    private func loadLyrics(for track: Track) {
        self.lyrics = []
        self.isLyricsSynced = false
        Task {
            let (synced, lines) = await LyricsService.shared.fetchLyrics(for: track)
            guard self.currentTrack?.id == track.id else { return }
            self.isLyricsSynced = synced
            self.lyrics = lines
            self.updateLyricIndex(for: self.effectivePlaybackTime(includeOffset: false))
        }
    }
    
    private func updateLyricIndex(for rawTime: TimeInterval) {
        guard isLyricsSynced && !lyrics.isEmpty else {
            currentLyricIndex = nil
            return
        }
        
        // Match using the same offset + perceptual lead as the KTV highlighter
        let time = rawTime + lyricOffset + 0.10
        var activeIndex: Int? = nil
        for (i, line) in lyrics.enumerated() {
            if time >= line.time {
                activeIndex = i
            } else {
                break
            }
        }
        if self.currentLyricIndex != activeIndex {
            self.currentLyricIndex = activeIndex
        }
    }
    
    // MARK: - Now Playing & Remote Control
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previous()
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in
                self?.seek(to: posEvent.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if let coverData = track.localCoverData, let image = NSImage(data: coverData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
