// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IShare",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "IShare",
            path: "Sources/IShare",
            exclude: ["Info.plist", "Resources"]
        )
    ]
)
