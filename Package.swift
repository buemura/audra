// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScreenReader",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ScreenReaderCore", targets: ["ScreenReaderCore"]),
    ],
    targets: [
        .target(name: "ScreenReaderCore"),
        .testTarget(name: "ScreenReaderCoreTests", dependencies: ["ScreenReaderCore"]),
    ]
)
