// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ARCMetrics",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ARCMetricsKit",
            targets: ["ARCMetricsKit"]
        )
    ],
    dependencies: [
        // ARCLogger - Local package de ARC Labs Studio
        .package(path: "../ARCLogger")
    ],
    targets: [
        .target(
            name: "ARCMetricsKit",
            dependencies: [
                .product(name: "ARCLogger", package: "ARCLogger")
            ],
            path: "Sources/ARCMetricsKit"
        ),
        .testTarget(
            name: "ARCMetricsKitTests",
            dependencies: ["ARCMetricsKit"],
            path: "Tests/ARCMetricsKitTests"
        )
    ]
)
