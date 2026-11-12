// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppleMusicPlayer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AppleMusicPlayer",
            path: "Sources"
        )
    ]
)
