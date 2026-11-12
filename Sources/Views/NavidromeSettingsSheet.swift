import SwiftUI

public struct NavidromeSettingsSheet: View {
    @Binding var isPresented: Bool
    var onConfigSaved: (() -> Void)?
    
    @UIState private var serverURL: String = ""
    @UIState private var username: String = ""
    @UIState private var password: String = ""
    @UIState private var allowInsecureTLS: Bool = true
    
    @UIState private var isTesting: Bool = false
    @UIState private var testResult: String? = nil
    @UIState private var isSuccess: Bool = false
    
    private let appleMusicRed = Color(red: 250/255, green: 45/255, blue: 72/255)
    
    public init(isPresented: Binding<Bool>, onConfigSaved: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.onConfigSaved = onConfigSaved
    }
    
    public var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 28))
                    .foregroundColor(appleMusicRed)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Navidrome 服务器设置")
                        .font(.system(size: 16, weight: .bold))
                    Text("输入您的 Navidrome / Subsonic 服务器地址与凭据")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)
            
            Divider()
            
            // Form Fields
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务器地址 (Server URL)")
                        .font(.system(size: 12, weight: .medium))
                    TextField("例如: https://music.yourdomain.com:8443", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("用户名 (Username)")
                        .font(.system(size: 12, weight: .medium))
                    TextField("Navidrome 用户名", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("密码 (Password)")
                        .font(.system(size: 12, weight: .medium))
                    SecureField("Navidrome 密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Allow Insecure TLS Checkbox
                Toggle(isOn: $allowInsecureTLS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("忽略 SSL/TLS 证书验证 (推荐开启)")
                            .font(.system(size: 12, weight: .medium))
                        Text("兼容自建私有云、DDNS 域名、自签名或私有 CA 证书，避免 TLS 安全连接失败")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Test connection result banner
            if let result = testResult {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? .green : .orange)
                        .font(.system(size: 14))
                        .padding(.top, 1)
                    
                    Text(result)
                        .font(.system(size: 12))
                        .foregroundColor(isSuccess ? .green : .primary)
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                )
            }
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("测试连接") {
                    testConnection()
                }
                .disabled(isTesting || serverURL.isEmpty || username.isEmpty)
                
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
                
                if NavidromeConfig.load() != nil {
                    Button("清除配置", role: .destructive) {
                        clearConfig()
                    }
                }
                
                Button("取消") {
                    isPresented = false
                }
                
                Button("保存并连接") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .tint(appleMusicRed)
                .disabled(serverURL.isEmpty || username.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 420)
        .onAppear {
            if let config = NavidromeConfig.load() {
                self.serverURL = config.serverURL
                self.username = config.username
                self.password = config.password
                self.allowInsecureTLS = config.allowInsecureTLS
            }
        }
    }
    
    private func cleanedURLString() -> String {
        var clean = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            // If port 443 or 8443, prefer https, else http
            if clean.contains(":8443") || clean.contains(":443") {
                clean = "https://" + clean
            } else {
                clean = "http://" + clean
            }
        }
        return clean
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let cleaned = cleanedURLString()
        let tempConfig = NavidromeConfig(
            serverURL: cleaned,
            username: username,
            password: password,
            allowInsecureTLS: allowInsecureTLS
        )
        
        Task {
            await NavidromeClient.shared.setConfig(tempConfig)
            do {
                let (version, serverType) = try await NavidromeClient.shared.testConnection()
                self.isSuccess = true
                self.testResult = "连接成功！服务器: \(serverType), API 版本: \(version)"
            } catch let err as SubsonicError {
                self.isSuccess = false
                self.testResult = "连接失败: \(err.localizedErrorMessage)"
            } catch {
                self.isSuccess = false
                let errString = error.localizedDescription
                if errString.contains("TLS") || errString.contains("安全连接失败") || errString.contains("证书") {
                    self.testResult = "TLS 证书校验失败。请确保已勾选【忽略 SSL/TLS 证书验证】，或尝试使用 HTTP 协议。"
                } else {
                    self.testResult = "连接失败: \(errString)"
                }
            }
            self.isTesting = false
        }
    }
    
    private func saveConfig() {
        let cleaned = cleanedURLString()
        let config = NavidromeConfig(
            serverURL: cleaned,
            username: username,
            password: password,
            allowInsecureTLS: allowInsecureTLS
        )
        Task {
            await NavidromeClient.shared.setConfig(config)
            await NavidromeManager.shared.checkConnection()
            onConfigSaved?()
            isPresented = false
        }
    }
    
    private func clearConfig() {
        NavidromeConfig.clear()
        Task {
            await NavidromeClient.shared.setConfig(NavidromeConfig())
            await NavidromeManager.shared.checkConnection()
            onConfigSaved?()
            isPresented = false
        }
    }
}
