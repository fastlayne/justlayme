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
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),

        // WebSocket for real-time features
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.6"),

        // Keychain storage for secure token management
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0"),

        // Image loading and caching
        .package(url: "https://github.com/kean/Nuke.git", from: "12.4.0"),

        // Stripe payments
        .package(url: "https://github.com/stripe/stripe-ios.git", from: "23.18.0"),

        // Google Sign-In
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.1.0")
    ],
    targets: [
        .target(
            name: "JustLayMe",
            dependencies: [
                "Alamofire",
                "Starscream",
                .product(name: "KeychainSwift", package: "keychain-swift"),
                "Nuke",
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JustLayMeTests",
            dependencies: ["JustLayMe"],
            path: "Tests/JustLayMeTests"
        )
    ]
)
