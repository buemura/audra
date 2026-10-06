// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ESpeakNG",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ESpeakNG", targets: ["ESpeakNG"]),
    ],
    targets: [
        .binaryTarget(name: "ESpeakNG", path: "ESpeakNG.xcframework"),
    ]
)
