import SwiftUI
import AppKit

@main
struct AppleMusicPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .background(VisualEffectView().ignoresSafeArea())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandMenu("控制") {
                Button("播放 / 暂停") {
                    PlayerManager.shared.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button("下一首") {
                    PlayerManager.shared.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("上一首") {
                    PlayerManager.shared.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Divider()
                
                Button("显示/隐藏歌词") {
                    PlayerManager.shared.showLyrics.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("显示/隐藏待播清单") {
                    PlayerManager.shared.showQueue.toggle()
                }
                .keyboardShortcut("u", modifiers: .command)
            }
            
            CommandMenu("显示") {
                Picker("主题外观", selection: Binding(
                    get: { themeManager.currentTheme },
                    set: { themeManager.currentTheme = $0 }
                )) {
                    ForEach(ThemeManager.Theme.allCases) { theme in
                        Label(theme.title, systemImage: theme.iconName).tag(theme)
                    }
                }
                
                Button("切换浅色 / 深色外观") {
                    themeManager.toggleLightDark()
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
