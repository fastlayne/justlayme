// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JustLayMeAPI",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "JustLayMeAPI",
            targets: ["JustLayMeAPI"]
        ),
    ],
    dependencies: [
        // No external dependencies - uses only Foundation and Combine
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "JustLayMeAPI",
            dependencies: [],
            path: "Sources/JustLayMeAPI"
        ),
        .testTarget(
            name: "JustLayMeAPITests",
            dependencies: ["JustLayMeAPI"],
            path: "Tests/JustLayMeAPITests"
        ),
    ]
)
