// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IdleIsle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "IdleIsle", targets: ["IdleIsle"])
    ],
    targets: [
        // Foundation-only simulation core. Must never import SpriteKit,
        // SwiftUI, or AppKit; the compiler now enforces that boundary.
        .target(
            name: "IdleEngine",
            path: "Sources/IdleEngine"
        ),
        .executableTarget(
            name: "IdleIsle",
            dependencies: ["IdleEngine"],
            path: "Sources/IdleIsle"
        ),
        .testTarget(
            name: "IdleEngineTests",
            dependencies: ["IdleEngine"],
            path: "Tests/IdleEngineTests"
        )
    ]
)
