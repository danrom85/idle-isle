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
        .executableTarget(
            name: "IdleIsle",
            path: "Sources/IdleIsle"
        ),
        .testTarget(
            name: "IdleIsleTests",
            dependencies: ["IdleIsle"],
            path: "Tests/IdleIsleTests"
        )
    ]
)
