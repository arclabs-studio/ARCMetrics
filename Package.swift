// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "ARCMetrics",

                      // MARK: - Platforms

                      // MetricKit backends: MetricManager on iOS / macOS 27, MXMetricManager on
                      // earlier iOS and visionOS. macOS before 27 builds but delivers nothing.
                      platforms: [.iOS(.v17),
                                  .macOS(.v14),
                                  .visionOS(.v1)],

                      // MARK: - Products

                      products: [.library(name: "ARCMetrics",
                                          targets: ["ARCMetrics"]),
                                 .library(name: "ARCMetricsMocks",
                                          targets: ["ARCMetricsMocks"])],

                      // MARK: - Dependencies

                      dependencies: [// ARCLogger - Structured logging for ARC Labs Studio
                          .package(url: "https://github.com/arclabs-studio/ARCLogger.git", from: "1.0.0")],

                      // MARK: - Targets

                      targets: [// Main library
                          .target(name: "ARCMetrics",
                                  dependencies: [.product(name: "ARCLogger", package: "ARCLogger")],
                                  path: "Sources/ARCMetrics"),

                          // Test doubles for consumers of ARCMetrics
                          .target(name: "ARCMetricsMocks",
                                  dependencies: ["ARCMetrics"],
                                  path: "Sources/ARCMetricsMocks"),

                          // Tests
                          .testTarget(name: "ARCMetricsTests",
                                      dependencies: ["ARCMetrics", "ARCMetricsMocks"],
                                      path: "Tests/ARCMetricsTests",
                                      resources: [.copy("Fixtures")])],

                      // MARK: - Swift Language

                      swiftLanguageModes: [.v6])
