import SwiftUI

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    public enum Theme: String, CaseIterable, Identifiable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        public var id: String { rawValue }
        
        public var title: String {
            switch self {
            case .light: return "浅色模式 (白色)"
            case .dark: return "深色模式 (黑色)"
            case .system: return "跟随系统"
            }
        }
        
        public var iconName: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }
        
        public var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    @Published public var currentTheme: Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "AppleMusicPlayer.Theme")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "AppleMusicPlayer.Theme") ?? "light"
        self.currentTheme = Theme(rawValue: saved) ?? .light
    }
    
    public func toggleLightDark() {
        if currentTheme == .light {
            currentTheme = .dark
        } else {
            currentTheme = .light
        }
    }
}
