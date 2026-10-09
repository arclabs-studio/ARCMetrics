# Changelog

All notable changes to ARCMetrics will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-10-09

Additive: spans that carry attributes, parent links and outcomes, for backends such as ARCMetricsOTel. `SignpostTracing` is unchanged. Guide: [Tracing with Attributes](Sources/ARCMetrics/ARCMetrics.docc/Articles/TracingWithAttributes.md).

### Added

- **`Tracing`** — `Sendable` protocol for spans and events that carry attributes, parent links and outcomes: `start(_:attributes:)`, `end(_:outcome:attributes:)`, `event(_:category:attributes:)`. Helpers `begin(_:category:parent:attributes:) -> TraceSpan`, and sync and async `trace(_:category:parent:attributes:operation:)`; the async one inherits the caller's isolation and returns `sending T`. A throwing operation ends its span with `.error(type:)`, the error's type name only — never its message.
- **`TraceSpan`** (random non-zero `id` that doubles as the `OSSignpostID`, `name`, `category`, `parentID`, `startTime`), **`TraceOutcome`** (`.ok`, `.error(type:)`), **`TraceAttributeValue`** (string, int, double, bool, with literal conformances) and **`TraceAttributes`**.
- **`TeeTracer`** forwards every call, in order, to several tracers with the same span token. **`NoOpTracer`** records nothing.
- **`MetricKitSignpostTracer` conforms to `Tracing`**: spans become signpost intervals keyed by the span `id`; attributes, parents and outcomes are ignored. `SignpostTracing` is unchanged.
- **`RecordingTracer`** in `ARCMetricsMocks`.
- DocC article *Tracing with Attributes*.

## [2.0.0] - 2026-10-07

ARCMetrics 2.0 moves to Apple's iOS / macOS 27 `MetricManager` API and replaces the callback singleton with an owned collector that publishes `AsyncStream`s. Step-by-step upgrade guide: [Migrating to ARCMetrics 2.0](Sources/ARCMetrics/ARCMetrics.docc/Articles/MigratingToV2.md).

### Breaking Changes

- **Removed `MetricKitProvider`**, including `MetricKitProvider.shared`, `configure(logger:)`, and the `onMetricPayloadsReceived` / `onDiagnosticPayloadsReceived` callbacks. Use `MetricsCollector`.
- **Removed the `MetricsProviding` protocol.** Use `MetricsCollecting`.
- **No singleton.** The app creates one `MetricsCollector` and keeps it for its lifetime. Apple recommends a single `MetricManager`; two iterators of the same report sequence each receive a non-deterministic subset of reports.
- **`MetricSummary.scrollHitchTimeRatio` is now `Double?` in milliseconds per second** (was `Double = 0`, documented as a percentage). It is `nil` on iOS and macOS 27, where `MetricManager` has no scroll-only metric — read `hitchTimeRatio` there.
- **`MockMetricsProvider` is gone.** The test double now ships as `MockMetricsCollector` in the new `ARCMetricsMocks` product.
- **Streams finish when their collector is released.** Keep the `MetricsCollector` (or `MockMetricsCollector`) alive for as long as you read from it; a `for await` loop over a released collector now ends instead of suspending forever.

### Added

- **`MetricsCollecting`** — `Sendable` protocol with `metricSummaries() -> AsyncStream<MetricSummary>`, `diagnosticSummaries() -> AsyncStream<DiagnosticSummary>`, `startCollecting()`, `stopCollecting()`, `isCollecting`, `pastMetricSummaries`, and `pastDiagnosticSummaries`. Every stream call is an independent subscriber that receives every summary delivered afterwards (multicast, no replay). In 1.x a second consumer assigning the callback silently replaced the first.
- **`MetricsCollector`** — the production `MetricsCollecting`, created with `init(logger:)` (defaults to `ARCLogger(category: "MetricKit")`). The MetricKit backend is chosen at runtime:
  - iOS 27 / macOS 27: Apple's `MetricManager` (`metricReports` / `diagnosticReports` async sequences). Compiled only with the Swift 6.4 toolchain (Xcode 27), via `#if compiler(>=6.4)`, because older SDKs do not contain it.
  - iOS below 27 and all visionOS: the `MXMetricManager` subscriber. Apple marks it to-be-deprecated; it still works and raises no warning at this package's deployment targets.
  - macOS below 27: no-op that logs a warning, as in 1.x.
- **`MetricSummary.hitchTimeRatio`** (`Double?`) — hitch time across all tracked animations, in milliseconds per second, perception-adjusted by Apple. Filled from `MetricManager`'s hitch-time metric on 27 and from `MXAnimationMetric.hitchTimeRatio` on the iOS / visionOS 26 legacy path. Apple's targets: under 5 ms/s good, 5–10 ms/s noticeable, above 10 ms/s investigate.
- **`ARCMetricsMocks` product**:
  - `MockMetricsCollector` — `simulate(metric:)`, `simulate(diagnostic:)`, `startCollectingCallCount`, `stopCollectingCallCount`, `init(pastMetricSummaries:pastDiagnosticSummaries:)`. Simulated summaries reach every current subscriber.
  - `RecordingSignpostTracer` — records `events` (`.emitted` / `.began` / `.ended`) and exposes `beginCount`, `endCount`, and `openedIDs`.

### Changed

- **Diagnostics on iOS / macOS 27**: each `DiagnosticReport` is one event and becomes one `DiagnosticSummary` holding one crash, one hang, or one CPU / disk-write exception. App-launch and memory-exception diagnostics produce no summary — `DiagnosticSummary` has no field for them.
- **`pastMetricSummaries` / `pastDiagnosticSummaries` on iOS / macOS 27** contain only summaries delivered in the current process: `MetricManager` has no history API. Below 27 they still read MetricKit's on-device history (`pastPayloads`).
- **Signposts** — `SignpostTracing`, `MetricKitSignpostTracer`, `SignpostCategory`, `SignpostInterval`, and `NoOpSignpostTracer` keep their API. The log handle now comes from `MetricManager.logHandle(category:)` on iOS / macOS 27 (`MXMetricManager.makeLogHandle(category:)` below 27 and on visionOS), and macOS 27 now emits through `mxSignpost` too. `mxSignpost` itself is not deprecated.
- **Concurrency** — every type is checked `Sendable`. 1.x had two `@unchecked Sendable` conformances; 2.0 has none.
- `MetricSummary` and `DiagnosticSummary` remain `Codable`; JSON written by 1.x decodes unchanged, with missing hitch fields decoding as `nil`.

### Fixed

- **`scrollHitchTimeRatio` was 100× too large.** 1.x multiplied MetricKit's value by 100, assuming a `0...1` ratio. MetricKit reports milliseconds per second (unit symbol measured on an iOS 27 device, 2026-10-06). 2.0 stores the value as reported. Summaries persisted by 1.x decode unchanged and are therefore still 100× too large.
- **1.x did not compile against the iOS 27 SDK.** From that SDK `import MetricKit` re-exports `os`, which made `Logger` ambiguous with ARCLogger's.
- **`hitchTimeRatio` on iOS / macOS 27 is converted to `HitchTimeRatio`'s base unit** (ms per second, per Apple's documentation) instead of trusting the encoded unit.

## [1.0.0] - 2026-08-21

First public release of **ARCMetrics**.

ARC Labs Studio re-baselined every package at `1.0.0` for its first product launch. The pre-launch version history (0.1.0 → 1.0.1) never corresponded to a release the studio stood behind; those tags and GitHub Releases have been removed and the notes are preserved below under [Pre-1.0 history](#pre-10-history-untagged).

### Added

- **Signpost tracing** — `SignpostTracing`, with `measure(_:category:operation:)` in sync and async form. The async overload takes `isolation: isolated (any Actor)? = #isolation` and returns `sending T`, so wrapping `@MainActor` work introduces no actor hop and imposes no `Sendable` requirement on the result.
- **`MetricKitSignpostTracer`** — emits through `mxSignpost` on an `MXMetricManager.makeLogHandle(category:)` handle, so one call feeds both MetricKit's 24-hour aggregate and the live Instruments trace. Only `mxSignpost` populates the CPU / memory / logical-writes measurements; `OSSignposter` on the same handle would not. Falls back to plain `os_signpost` off iOS/visionOS.
- **`SignpostCategory`** — `ExpressibleByStringLiteral`, with `launch`, `persistence`, `network`, `media`, and `intelligence` as the studio's shared vocabulary.
- **`SignpostInterval`** — opaque in-flight token carrying the `StaticString` the interval opened with, since the signpost API requires the same literal to close it.
- **`NoOpSignpostTracer`** — for tests, and as the fallback where signposts are unavailable.
- **Payload-source seam** — `MetricPayloadSource` / `DiagnosticPayloadSource`, plain protocols in normalized units that `MXMetricPayload` / `MXDiagnosticPayload` conform to behind an `#if`. Makes the transformation layer testable on macOS CI, and is the migration path for iOS 27's `MetricManager` / `MetricReport`.
- **`MetricSummary.interval` / `DiagnosticSummary.interval`** (`DateInterval?`) — locale-independent, comparable reporting period. Prefer it over `timeRange`, which is display-only.
- **`MetricKitProvider.configure(logger:)`** — injects any `ARCLogger.Logger`. Call before `startCollecting()`.
- **`MetricKitProvider.isCollecting`**.
- Public memberwise initialisers on `DiagnosticSummary.CrashInfo` and `DiagnosticSummary.HangInfo`, so consumers can build fixtures.
- 33 Swift Testing cases covering histogram arithmetic, `Codable` compatibility, and provider state. New tests are written in Swift Testing; the existing XCTest suite still runs.

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

- **`MetricKitProvider` is now internally synchronised.** Callbacks were bare `var`s under `@unchecked Sendable`, written from the main thread at launch and read from MetricKit's delivery thread. All mutable state moved behind one `OSAllocatedUnfairLock`; callbacks are copied out before invocation, so a re-entrant handler cannot deadlock.
- **`startCollecting()` / `stopCollecting()` are idempotent.** A duplicate `startCollecting()` previously called `MXMetricManager.add(self)` again and delivered every payload twice — reachable in any app that rebuilds its composition root.
- **`pastMetricSummaries` / `pastDiagnosticSummaries` are memoized** by reporting interval instead of reprocessing the whole history on every read.
- Per-payload logging demoted to `.debug`; `.error` reserved for payloads that contain a crash.
- DocC catalog moved to `Sources/ARCMetrics/ARCMetrics.docc/` so its articles build.

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

### Fixed

- `MetricSummary` and `DiagnosticSummary` decode tolerantly. Synthesized `Codable` required every key, so summaries archived before `interval` existed would have failed to decode.
- README no longer advertises a "Battery / Energy" metric this package has never collected.

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

[2.1.0]: https://github.com/arclabs-studio/ARCMetrics/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/arclabs-studio/ARCMetrics/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/arclabs-studio/ARCMetrics/releases/tag/v1.0.0
