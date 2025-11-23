// swift-tools-version: 5.9
// JustLayMe iOS - Swift Package Configuration

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
    dependencies: [],
    targets: [
        .target(
            name: "JustLayMe",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("CoreData/JustLayMe.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "JustLayMeTests",
            dependencies: ["JustLayMe"],
            path: "Tests"
        ),
    ]
)
