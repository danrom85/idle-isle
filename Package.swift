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
        // SpriteKit presentation shared by every host: the macOS app today,
        // the screensaver plug-in built by Tools/build_saver.sh.
        .target(
            name: "IdleWorld",
            dependencies: ["IdleEngine"],
            path: "Sources/IdleWorld"
        ),
        .executableTarget(
            name: "IdleIsle",
            dependencies: ["IdleWorld"],
            path: "Sources/IdleIsle"
        ),
        .testTarget(
            name: "IdleEngineTests",
            dependencies: ["IdleEngine"],
            path: "Tests/IdleEngineTests"
        )
    ]
)
