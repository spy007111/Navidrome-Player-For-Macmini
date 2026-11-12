import SwiftUI

public enum NavigationSection: Hashable, Identifiable {
    case listenNow
    case browse
    case recentlyAdded
    case artists
    case albums
    case songs
    case localMusic
    case navidrome
    
    public var id: String {
        switch self {
        case .listenNow: return "listenNow"
        case .browse: return "browse"
        case .recentlyAdded: return "recentlyAdded"
        case .artists: return "artists"
        case .albums: return "albums"
        case .songs: return "songs"
        case .localMusic: return "localMusic"
        case .navidrome: return "navidrome"
        }
    }
    
    public var title: String {
        switch self {
        case .listenNow: return "现在就听"
        case .browse: return "浏览"
        case .recentlyAdded: return "最近添加"
        case .artists: return "艺人"
        case .albums: return "专辑"
        case .songs: return "歌曲"
        case .localMusic: return "本地音乐"
        case .navidrome: return "Navidrome"
        }
    }
    
    public var icon: String {
        switch self {
        case .listenNow: return "play.circle.fill"
        case .browse: return "square.grid.2x2.fill"
        case .recentlyAdded: return "clock.fill"
        case .artists: return "music.mic"
        case .albums: return "square.stack.fill"
        case .songs: return "music.note"
        case .localMusic: return "laptopcomputer"
        case .navidrome: return "server.rack"
        }
    }
}

public struct SidebarView: View {
    @Binding var selection: NavigationSection?
    @ObservedObject var localLibrary = LocalLibraryManager.shared
    @ObservedObject var navidromeManager = NavidromeManager.shared
    @UIState private var showSettingsSheet: Bool = false
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(selection: Binding<NavigationSection?>) {
        self._selection = selection
    }
    
    public var body: some View {
        List(selection: $selection) {
            Section("Apple Music") {
                NavigationLink(value: NavigationSection.listenNow) {
                    Label(NavigationSection.listenNow.title, systemImage: NavigationSection.listenNow.icon)
                }
                .accentColor(appleMusicRed)
                
                NavigationLink(value: NavigationSection.browse) {
                    Label(NavigationSection.browse.title, systemImage: NavigationSection.browse.icon)
                }
            }
            
            Section("资料库") {
                NavigationLink(value: NavigationSection.recentlyAdded) {
                    Label(NavigationSection.recentlyAdded.title, systemImage: NavigationSection.recentlyAdded.icon)
                }
                
                NavigationLink(value: NavigationSection.artists) {
                    Label(NavigationSection.artists.title, systemImage: NavigationSection.artists.icon)
                }
                
                NavigationLink(value: NavigationSection.albums) {
                    Label(NavigationSection.albums.title, systemImage: NavigationSection.albums.icon)
                }
                
                NavigationLink(value: NavigationSection.songs) {
                    Label(NavigationSection.songs.title, systemImage: NavigationSection.songs.icon)
                }
            }
            
            Section("音乐源") {
                NavigationLink(value: NavigationSection.localMusic) {
                    HStack {
                        Label(NavigationSection.localMusic.title, systemImage: NavigationSection.localMusic.icon)
                        Spacer()
                        if localLibrary.tracks.count > 0 {
                            Text("\(localLibrary.tracks.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                NavigationLink(value: NavigationSection.navidrome) {
                    HStack {
                        Label(NavigationSection.navidrome.title, systemImage: NavigationSection.navidrome.icon)
                        Spacer()
                        Circle()
                            .fill(navidromeManager.isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            navidromeStatusFooter
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavidromeSettingsSheet(isPresented: $showSettingsSheet) {
                Task {
                    await navidromeManager.checkConnection()
                }
            }
        }
    }
    
    private var navidromeStatusFooter: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Navidrome")
                        .font(.system(size: 11, weight: .semibold))
                    Text(navidromeManager.isConnected ? (navidromeManager.serverInfo.isEmpty ? "已连接服务器" : navidromeManager.serverInfo) : "未连接")
                        .font(.system(size: 10))
                        .foregroundColor(navidromeManager.isConnected ? .green : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: { showSettingsSheet = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("配置 Navidrome 服务器")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}
