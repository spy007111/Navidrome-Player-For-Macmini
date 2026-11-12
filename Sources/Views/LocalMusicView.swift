import SwiftUI
import AppKit

public struct LocalMusicView: View {
    public var onSelectAlbum: (Album) -> Void
    public var onPlayAlbum: (Album) -> Void
    
    @ObservedObject var localManager = LocalLibraryManager.shared
    @UIState private var selectedTab: Int = 0 // 0: 歌曲, 1: 专辑, 2: 艺人, 3: 目录管理
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(onSelectAlbum: @escaping (Album) -> Void, onPlayAlbum: @escaping (Album) -> Void) {
        self.onSelectAlbum = onSelectAlbum
        self.onPlayAlbum = onPlayAlbum
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地音乐")
                        .font(.system(size: 26, weight: .bold))
                    Text("\(localManager.tracks.count) 首歌曲 • \(localManager.albums.count) 张专辑")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Segmented Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("歌曲").tag(0)
                    Text("专辑").tag(1)
                    Text("艺人").tag(2)
                    Text("文件夹").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                
                // Rescan Button
                Button(action: {
                    Task {
                        await localManager.scanAllFolders()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("扫描")
                            .font(.system(size: 12))
                    }
                }
                .disabled(localManager.isScanning)
                
                // Add Folder Button
                Button(action: chooseFolder) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                }
                .help("添加本地音乐文件夹")
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Scanning progress banner if scanning
            if localManager.isScanning {
                VStack(spacing: 4) {
                    ProgressView(value: localManager.scanProgress)
                        .progressViewStyle(.linear)
                    Text(localManager.scanStatus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
            }
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    SongsTableView(title: "", tracks: localManager.tracks)
                case 1:
                    AlbumsGridView(
                        title: "",
                        albums: localManager.albums,
                        onSelectAlbum: onSelectAlbum,
                        onPlayAlbum: onPlayAlbum
                    )
                case 2:
                    artistsListView
                case 3:
                    folderManagementView
                default:
                    EmptyView()
                }
            }
        }
    }
    
    private var artistsListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(localManager.artists) { artist in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "music.mic")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(artist.albumCount) 张专辑")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
                    Divider()
                        .padding(.leading, 86)
                }
            }
            .padding(.vertical, 12)
        }
    }
    
    private var folderManagementView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("监控的音乐文件夹")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 16)
            
            Text("播放器会自动索引所选文件夹及其子目录中的音频文件（支持 MP3, M4A, FLAC, WAV, AAC, ALAC 等格式）")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            List {
                ForEach(localManager.musicFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(folder)
                            .font(.system(size: 13, design: .monospaced))
                        Spacer()
                        Button(action: { localManager.removeFolder(path: folder) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("移除此文件夹")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .frame(maxHeight: 240)
            
            Button("添加音乐文件夹...") {
                chooseFolder()
            }
            .buttonStyle(.borderedProminent)
            .tint(appleMusicRed)
            
            Spacer()
        }
        .padding(28)
    }
    
    private func chooseFolder() {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "选择"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            localManager.addFolder(path: selectedURL.path)
        }
    }
}
