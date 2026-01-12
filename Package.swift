// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ARCMetrics",

    // MARK: - Platforms

    // Note: MetricKit is only available on iOS and visionOS.
    // macOS is included for development tooling compatibility only.
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],

    // MARK: - Products

    products: [
        .library(
            name: "ARCMetrics",
            targets: ["ARCMetrics"]
        )
    ],

    // MARK: - Dependencies

    dependencies: [
        // ARCLogger - Structured logging for ARC Labs Studio
        .package(url: "https://github.com/arclabs-studio/ARCLogger.git", from: "1.0.0")
    ],

    // MARK: - Targets

    targets: [
        // Main library
        .target(
            name: "ARCMetrics",
            dependencies: [
                .product(name: "ARCLogger", package: "ARCLogger")
            ],
            path: "Sources/ARCMetrics",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // Tests
        .testTarget(
            name: "ARCMetricsTests",
            dependencies: ["ARCMetrics"],
            path: "Tests/ARCMetricsTests"
        )
    ],

    // MARK: - Swift Language

    swiftLanguageModes: [.v6]
)
