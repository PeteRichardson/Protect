// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Protect",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Protect",
            targets: ["Protect"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.9.1"))
    ],
    targets: [
        .target(
            name: "Protect"
        ),
        .testTarget(
            name: "ProtectTests",
            dependencies: ["Protect"]
        ),
    ]
)
