// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShowcaseApp",

    // MARK: - Platforms

    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],

    // MARK: - Products

    products: [
        .executable(
            name: "ShowcaseApp",
            targets: ["ShowcaseApp"]
        )
    ],

    // MARK: - Dependencies

    dependencies: [
        // ARCMetrics - Parent package
        .package(path: "../..")
    ],

    // MARK: - Targets

    targets: [
        .executableTarget(
            name: "ShowcaseApp",
            dependencies: [
                .product(name: "ARCMetricsKit", package: "ARCMetrics")
            ],
            path: "Sources/ShowcaseApp",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ],

    // MARK: - Swift Language

    swiftLanguageModes: [.v6]
)
