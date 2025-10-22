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
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.8.0")
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
