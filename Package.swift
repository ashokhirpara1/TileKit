// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TileKit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TileKit",
            path: "TileKit",
            resources: [.copy("Resources/AppIcon.icns")]
        ),
    ]
)
