import Foundation
import SwiftUI

@MainActor
public final class NavidromeManager: ObservableObject {
    public static let shared = NavidromeManager()
    
    @Published public var isConnected: Bool = false
    @Published public var serverInfo: String = ""
    @Published public var isChecking: Bool = false
    
    private init() {
        Task {
            await checkConnection()
        }
    }
    
    public func checkConnection() async {
        guard let config = NavidromeConfig.load(), config.isValid else {
            self.isConnected = false
            self.serverInfo = ""
            return
        }
        
        self.isChecking = true
        do {
            let (ver, type) = try await NavidromeClient.shared.testConnection()
            self.isConnected = true
            self.serverInfo = "\(type) v\(ver)"
        } catch {
            self.isConnected = false
            self.serverInfo = ""
        }
        self.isChecking = false
    }
}
