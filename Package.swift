// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Commander",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Commander",
            path: "Sources/Commander",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
