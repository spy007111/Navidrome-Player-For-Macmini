import SwiftUI

public struct NavidromeView: View {
    public var onSelectAlbum: (Album) -> Void
    public var onPlayAlbum: (Album) -> Void
    
    @ObservedObject var navidromeManager = NavidromeManager.shared
    @UIState private var showSettings: Bool = false
    
    @UIState private var filterType: String = "recent" // all_songs, recent, newest, frequent, random, alphabeticalByArtist
    @UIState private var albums: [Album] = []
    @UIState private var isLoadingAlbums: Bool = false
    
    @UIState private var songs: [Track] = []
    @UIState private var isLoadingSongs: Bool = false
    
    @UIState private var searchQuery: String = ""
    @UIState private var searchResultsSongs: [Track] = []
    @UIState private var searchResultsAlbums: [Album] = []
    @UIState private var isSearching: Bool = false
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(onSelectAlbum: @escaping (Album) -> Void, onPlayAlbum: @escaping (Album) -> Void) {
        self.onSelectAlbum = onSelectAlbum
        self.onPlayAlbum = onPlayAlbum
    }
    
    public var body: some View {
        Group {
            if navidromeManager.isChecking && !navidromeManager.isConnected {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在连接 Navidrome 服务器...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !navidromeManager.isConnected {
                notConnectedView
            } else {
                connectedContentView
            }
        }
        .task {
            if navidromeManager.isConnected && albums.isEmpty && songs.isEmpty {
                await loadCurrentTab()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavidromeSettingsSheet(isPresented: $showSettings) {
                Task {
                    await navidromeManager.checkConnection()
                    await loadCurrentTab()
                }
            }
        }
    }
    
    private var notConnectedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(appleMusicRed.opacity(0.1))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "server.rack")
                    .font(.system(size: 40))
                    .foregroundColor(appleMusicRed)
            }
            
            VStack(spacing: 6) {
                Text("连接您的 Navidrome 音乐服务器")
                    .font(.system(size: 20, weight: .bold))
                
                Text("畅听您私人服务器上的海量无损音乐，全平台同步，实时串流")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
            Button("配置服务器连接") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(appleMusicRed)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private var connectedContentView: some View {
        VStack(spacing: 0) {
            // Header & Search
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Navidrome")
                            .font(.system(size: 26, weight: .bold))
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    if !navidromeManager.serverInfo.isEmpty {
                        Text(navidromeManager.serverInfo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Server Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("在服务器中搜索...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResultsSongs = []
                            searchResultsAlbums = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 240)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                
                // Settings button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("服务器设置")
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Sub-category filters (if not searching)
            if searchQuery.isEmpty {
                HStack(spacing: 8) {
                    filterTab(title: "最近添加", type: "recent")
                    filterTab(title: "所有歌曲", type: "all_songs")
                    filterTab(title: "最新发行", type: "newest")
                    filterTab(title: "最常播放", type: "frequent")
                    filterTab(title: "随机探索", type: "random")
                    filterTab(title: "全部专辑", type: "alphabeticalByArtist")
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            }
            
            Divider()
            
            // Content
            if isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在搜索...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchQuery.isEmpty {
                searchResultsView
            } else if filterType == "all_songs" {
                if isLoadingSongs {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在载入所有歌曲...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SongsTableView(title: "", tracks: songs)
                }
            } else {
                if isLoadingAlbums {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在加载专辑...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AlbumsGridView(
                        title: "",
                        albums: albums,
                        onSelectAlbum: onSelectAlbum,
                        onPlayAlbum: onPlayAlbum
                    )
                }
            }
        }
    }
    
    private func filterTab(title: String, type: String) -> some View {
        let isSelected = filterType == type
        return Button(action: {
            filterType = type
            Task { await loadCurrentTab() }
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? appleMusicRed : Color.secondary.opacity(0.12))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !searchResultsAlbums.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("专辑结果")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 28)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(searchResultsAlbums) { album in
                                    AlbumCardView(
                                        album: album,
                                        onSelect: { onSelectAlbum(album) },
                                        onPlay: { onPlayAlbum(album) }
                                    )
                                    .frame(width: 150)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
                
                if !searchResultsSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("单曲结果 (\(searchResultsSongs.count))")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 28)
                        
                        SongsTableView(title: "", tracks: searchResultsSongs)
                    }
                }
                
                if searchResultsAlbums.isEmpty && searchResultsSongs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("未找到与“\(searchQuery)”匹配的结果")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.top, 16)
        }
    }
    
    private func loadCurrentTab() async {
        if filterType == "all_songs" {
            await loadSongs()
        } else {
            await loadAlbums()
        }
    }
    
    private func loadAlbums() async {
        isLoadingAlbums = true
        do {
            self.albums = try await NavidromeClient.shared.getAlbums(type: filterType, size: 80)
        } catch {
            print("Failed to load albums: \(error)")
        }
        isLoadingAlbums = false
    }
    
    private func loadSongs() async {
        isLoadingSongs = true
        do {
            self.songs = try await NavidromeClient.shared.getSongs(size: 500)
        } catch {
            print("Failed to load songs: \(error)")
        }
        isLoadingSongs = false
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            do {
                let (songs, albums, _) = try await NavidromeClient.shared.search(query: searchQuery)
                self.searchResultsSongs = songs
                self.searchResultsAlbums = albums
            } catch {
                print("Search error: \(error)")
            }
            self.isSearching = false
        }
    }
}
