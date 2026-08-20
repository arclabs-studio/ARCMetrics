# Changelog

All notable changes to ARCMetrics will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-20

First public release of **ARCMetrics**.

ARC Labs Studio re-baselined every package at `1.0.0` for its first product launch. The pre-launch version history (0.1.0 → 1.0.1) never corresponded to a release the studio stood behind; those tags and GitHub Releases have been removed and the notes are preserved below under [Pre-1.0 history](#pre-10-history-untagged).

### Added

- **`INTERNAL-USE.md`** — documents ARC Labs Studio's self-grant for commercial use of its own products under the new licence.

- ARCDevTools integration for quality automation
- SwiftLint and SwiftFormat configuration
- GitHub Actions CI/CD workflows
- Git hooks for pre-commit and pre-push checks
- Documentation.docc catalog with comprehensive guides
- Claude Code skills for package validation
- `MetricsProviding` protocol for dependency injection and testing
- `pastMetricSummaries` and `pastDiagnosticSummaries` for historical data access
- `Codable` conformance to `MetricSummary` and `DiagnosticSummary`
- `Equatable` and `Hashable` conformance to all models
- `cumulativeGPUTimeSeconds` metric for GPU performance tracking
- `cumulativeDiskWritesMB` metric for disk I/O monitoring
- `scrollHitchTimeRatio` metric for animation performance analysis
- `MockMetricsProvider` for comprehensive testing support
- Reorganized test structure with Unit/ and Helpers/Mocks/ directories
- `MetricSummaryTests` with 11 comprehensive tests
- `DiagnosticSummaryTests` with 12 tests including Codable/Equatable/Hashable
- `MetricKitProviderTests` with 10 tests for singleton and protocol conformance
- `MockMetricsProviderTests` with 16 tests covering all mock functionality

### Changed

- **BREAKING:** Renamed library from `ARCMetricsKit` to `ARCMetrics` for consistency with ARC Labs package naming standards
- Renamed `Sources/ARCMetricsKit/` to `Sources/ARCMetrics/`
- Renamed `Tests/ARCMetricsKitTests/` to `Tests/ARCMetricsTests/`
- Moved `Documentation.docc` to package root as per ARC Labs standards
- Updated all imports from `import ARCMetricsKit` to `import ARCMetrics`

- Updated Package.swift with Swift 6 strict concurrency settings
- Improved code organization following ARCKnowledge standards
- `MetricKitProvider` now conforms to `MetricsProviding` protocol
- Callbacks now marked as `@Sendable` for Swift 6 concurrency safety
- `MetricKitPayloadProcessor` now extracts GPU, disk, and animation metrics

- **License** — relicensed from MIT to [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0). Source-available and free for non-commercial use; commercial use requires a separate licence from ARC Labs Studio. ARC Labs Studio's own products are covered by an internal grant — see `INTERNAL-USE.md`.

---

## Pre-1.0 history (untagged)

Everything below predates the 1.0.0 baseline. The version numbers are retained for traceability only — no tag or release exists for any of them.

### [0.1.0] - 2025-01-05

#### Added
- Initial development release
- `MetricKitProvider` singleton for MetricKit subscription
- `MetricKitPayloadProcessor` for transforming MX payloads
- `MetricSummary` model for performance metrics
- `DiagnosticSummary` model for crash and hang diagnostics
- Basic XCTest suite for provider and models
- ShowcaseApp example demonstrating integration
- Comprehensive DocC documentation in source code
- README with installation and usage instructions

#### Features
- Memory metrics (peak and average usage)
- CPU metrics (cumulative time, percentage calculation)
- Display metrics (hang time tracking)
- Launch metrics (time to first draw)
- Network metrics (cellular and WiFi transfer)
- Crash diagnostics with exception details
- Hang diagnostics with duration tracking
- Disk write and CPU exception counting

#### Dependencies
- ARCLogger for structured logging

---

<!-- Links will be added when releases are created -->
<!-- [Unreleased]: https://github.com/arclabs-studio/ARCMetrics/compare/v0.1.0...HEAD -->
<!-- [0.1.0]: https://github.com/arclabs-studio/ARCMetrics/releases/tag/v0.1.0 -->

---

[1.0.0]: https://github.com/arclabs-studio/ARCMetrics/releases/tag/v1.0.0
