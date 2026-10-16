// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Audra",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Audra", targets: ["ScreenReaderApp"]),
        .library(name: "ScreenReaderCore", targets: ["ScreenReaderCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.2"),
        .package(url: "https://github.com/mlalma/MisakiSwift", exact: "1.0.6"),
        .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6"),
        .package(path: "Packages/KokoroSwift"),
        .package(path: "Packages/ESpeakNG"),
    ],
    targets: [
        .target(name: "ScreenReaderCore"),
        // Everything that links MLX, MisakiSwift or eSpeak NG.
        .target(
            name: "ScreenReaderKokoro",
            dependencies: [
                "ScreenReaderCore",
                .product(name: "KokoroSwift", package: "KokoroSwift"),
                .product(name: "ESpeakNG", package: "ESpeakNG"),
                .product(name: "MisakiSwift", package: "MisakiSwift"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary"),
            ]
        ),
        .executableTarget(
            name: "ScreenReaderApp",
            dependencies: ["ScreenReaderCore", "ScreenReaderKokoro", "KeyboardShortcuts"],
            // The app bundle keeps the package frameworks (MLX, KokoroSwift, …) in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "ScreenReaderCoreTests", dependencies: ["ScreenReaderCore"]),
        .testTarget(name: "ScreenReaderKokoroTests", dependencies: ["ScreenReaderKokoro"]),
    ],
    swiftLanguageModes: [.v5]
)
