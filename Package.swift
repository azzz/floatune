// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Floatune",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Floatune", path: "Sources/Floatune")
    ]
)
