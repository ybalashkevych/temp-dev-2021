// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiveAssistant",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LiveAssistant",
            targets: ["LiveAssistant"]
        ),
    ],
    dependencies: [
        // Dependency Injection
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.8.0"),

        // SwiftGen for type-safe resource access
        .package(url: "https://github.com/SwiftGen/SwiftGenPlugin", from: "6.6.0"),

        // Recommended dependencies for AI/Communication features:
        // Add these as needed for your specific requirements

        // For networking (if not using URLSession directly)
        // .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),

        // For JSON parsing (if more control needed than Codable)
        // .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),

        // For WebSocket communication
        // .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),

        // For API client generation
        // .package(url: "https://github.com/CreateAPI/Get.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "LiveAssistant",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
            ],
            path: "LiveAssistant",
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
            ]
        ),
        .testTarget(
            name: "LiveAssistantTests",
            dependencies: ["LiveAssistant"],
            path: "LiveAssistantTests"
        ),
        .testTarget(
            name: "LiveAssistantUITests",
            dependencies: ["LiveAssistant"],
            path: "LiveAssistantUITests"
        ),
    ]
)
