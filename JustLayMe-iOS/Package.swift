// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JustLayMe",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "JustLayMe",
            targets: ["JustLayMe"]
        )
    ],
    dependencies: [
        // Networking
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),

        // Image Loading & Caching
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),

        // Keychain Access
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0"),

        // WebSocket
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),

        // JSON Parsing (already in Foundation, but Codable extensions)
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),

        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),

        // Linting (dev only)
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.52.0")
    ],
    targets: [
        .target(
            name: "JustLayMe",
            dependencies: [
                "Alamofire",
                "Nuke",
                .product(name: "KeychainSwift", package: "keychain-swift"),
                "Starscream",
                "SwiftyJSON",
                .product(name: "Logging", package: "swift-log")
            ],
            path: ".",
            exclude: ["Package.swift", "README.md"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JustLayMeTests",
            dependencies: ["JustLayMe"],
            path: "Tests"
        )
    ]
)
