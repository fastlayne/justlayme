// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JustLayMe",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "JustLayMe",
            targets: ["JustLayMe"]
        ),
    ],
    dependencies: [
        // Testing
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
        // Networking (optional)
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
    ],
    targets: [
        .target(
            name: "JustLayMe",
            dependencies: [],
            path: "JustLayMe/Sources"
        ),
        .testTarget(
            name: "JustLayMeTests",
            dependencies: [
                "JustLayMe",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "JustLayMeTests"
        ),
        .testTarget(
            name: "JustLayMeSnapshotTests",
            dependencies: [
                "JustLayMe",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "JustLayMeSnapshotTests"
        ),
    ]
)
