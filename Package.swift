// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScreenReader",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ScreenReader", targets: ["ScreenReaderApp"]),
        .library(name: "ScreenReaderCore", targets: ["ScreenReaderCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(name: "ScreenReaderCore"),
        .executableTarget(
            name: "ScreenReaderApp",
            dependencies: ["ScreenReaderCore", "KeyboardShortcuts"]
        ),
        .testTarget(name: "ScreenReaderCoreTests", dependencies: ["ScreenReaderCore"]),
    ]
)
