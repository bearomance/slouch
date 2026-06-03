// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Slouch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SlouchCore"),
        .testTarget(name: "SlouchCoreTests", dependencies: ["SlouchCore"]),
        .executableTarget(name: "Slouch", dependencies: ["SlouchCore"]),
    ]
)
