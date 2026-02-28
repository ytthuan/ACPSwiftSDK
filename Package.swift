// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ACPSwiftSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ACP", targets: ["ACP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "ACP",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/ACP",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ACPTests",
            dependencies: ["ACP"],
            path: "Tests/ACPTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
