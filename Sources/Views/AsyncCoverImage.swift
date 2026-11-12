import SwiftUI
import AppKit

public struct AsyncCoverImage: View {
    public let localData: Data?
    public let coverArtPath: String?
    public let urlString: String?
    public let cornerRadius: CGFloat
    
    @UIState private var displayImage: NSImage? = nil
    @UIState private var isLoading: Bool = false
    
    public init(
        localData: Data? = nil,
        coverArtPath: String? = nil,
        urlString: String? = nil,
        cornerRadius: CGFloat = 6
    ) {
        self.localData = localData
        self.coverArtPath = coverArtPath
        self.urlString = urlString
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        Group {
            if let image = displayImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                placeholderView(isLoading: true)
            } else {
                placeholderView(isLoading: false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .task(id: cacheKey) {
            await loadImage()
        }
    }
    
    private var cacheKey: String {
        if let path = coverArtPath, !path.isEmpty { return "file:\(path)" }
        if let url = urlString, !url.isEmpty { return "url:\(url)" }
        if let data = localData { return "data:\(data.count)" }
        return "empty"
    }
    
    private func loadImage() async {
        let key = cacheKey
        guard key != "empty" else { return }
        
        // 1. Check memory cache first
        if let cached = ImageCache.shared.get(for: key) {
            self.displayImage = cached
            return
        }
        
        self.isLoading = true
        
        // 2. Load from disk file path if present
        if let path = coverArtPath, !path.isEmpty {
            let img = await Task.detached(priority: .utility) { () -> NSImage? in
                if FileManager.default.fileExists(atPath: path),
                   let image = NSImage(contentsOfFile: path) {
                    return image
                }
                return nil
            }.value
            
            if let img = img {
                ImageCache.shared.set(img, for: key)
                self.displayImage = img
                self.isLoading = false
                return
            }
        }
        
        // 3. Load from remote URL if present
        if let urlStr = urlString, !urlStr.isEmpty {
            let img = await NavidromeClient.shared.fetchImage(from: urlStr)
            if let img = img {
                ImageCache.shared.set(img, for: key)
                self.displayImage = img
                self.isLoading = false
                return
            }
        }
        
        // 4. Fallback to raw data if present
        if let data = localData {
            let img = await Task.detached(priority: .utility) { () -> NSImage? in
                return NSImage(data: data)
            }.value
            
            if let img = img {
                ImageCache.shared.set(img, for: key)
                self.displayImage = img
            }
        }
        
        self.isLoading = false
    }
    
    private func placeholderView(isLoading: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.18), Color.gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
}
