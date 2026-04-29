// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MyDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MyDeskCore", targets: ["MyDeskCore"]),
        .executable(name: "MyDesk", targets: ["MyDesk"])
    ],
    targets: [
        .target(
            name: "MyDeskCore",
            path: "Sources/MyDeskCore"
        ),
        .executableTarget(
            name: "MyDesk",
            dependencies: ["MyDeskCore"],
            path: "Sources/MyDesk",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "MyDeskCoreTests",
            dependencies: ["MyDeskCore"],
            path: "Tests/MyDeskCoreTests"
        )
    ]
)
