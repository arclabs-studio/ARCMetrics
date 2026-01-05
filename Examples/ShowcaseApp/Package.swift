// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShowcaseApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ShowcaseApp",
            targets: ["ShowcaseApp"]
        )
    ],
    dependencies: [
        // ARCMetrics - Parent package
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "ShowcaseApp",
            dependencies: [
                .product(name: "ARCMetricsKit", package: "ARCMetrics")
            ],
            path: "Sources/ShowcaseApp",
            resources: [.process("Assets.xcassets")]
        )
    ]
)
