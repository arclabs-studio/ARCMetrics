# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a single test file
swift test --filter ARCMetricsTests

# Generate DocC documentation
swift package generate-documentation
```

**Known toolchain warning (Xcode 27, 2026-10-06):** linking the test bundle for an iOS
simulator emits `Using sysroot for 'macOS 27.0' but targeting
'arm64-apple-ios17.0.0-simulator' [-Wincompatible-sysroot]`. It reproduces in a fresh
trivial package, is not caused by this package, and has no `Package.swift` lever. The
library builds themselves (iOS, macOS, visionOS) are warning-free — check those.

**The `MetricManager` path (iOS/macOS 27) compiles only with Swift 6.4+** (`#if compiler(>=6.4)`),
so `swift test` on an older Xcode exercises the legacy path only. Real MetricKit payloads for
the fixtures come from Xcode → Debug → MetricKit → Simulate MetricKit Payloads, which exists
only when running on a **physical device**.

## Package Overview

ARCMetrics is a Swift package providing native MetricKit integration for collecting production performance metrics. It wraps Apple's MetricKit framework to deliver simplified `MetricSummary` and `DiagnosticSummary` models through `AsyncStream`s.

**Platforms:** iOS 17+, macOS 14+, visionOS 1+ (macOS before 27 has no MetricKit backend: the collector logs a warning and delivers nothing)
**Swift:** 6.0 tools; the iOS/macOS 27 `MetricManager` code compiles only with Swift 6.4 (Xcode 27), gated by `#if compiler(>=6.4)`
**Dependencies:** ARCLogger (remote, `https://github.com/arclabs-studio/ARCLogger.git`, from 1.0.0)
**Products:** `ARCMetrics`, `ARCMetricsMocks` (test doubles)

## Package Architecture

```
Sources/ARCMetrics/
├── MetricsCollector.swift           # Public collector: start/stop state, multicast streams
├── MetricKitPayloadProcessor.swift  # Transforms payload sources → summary models
├── Internal/
│   ├── DefaultMetricsBackend.swift  # Picks the backend at runtime
│   ├── MetricManagerBackend.swift   # iOS/macOS 27: MetricManager report sequences
│   ├── LegacyMXBackend.swift        # iOS < 27 + visionOS: MXMetricManager subscriber
│   ├── MetricsBackend.swift         # Backend protocol + MetricsDelivery
│   ├── UnavailableMetricsBackend.swift  # macOS < 27: logs a warning, delivers nothing
│   ├── MetricReportStreams.swift    # Seam over MetricManager's report sequences (fixtures in tests)
│   ├── SummaryCache.swift           # Per-interval memo for the MXMetricManager backend
│   ├── SummaryBroadcaster.swift     # `package` AsyncStream fan-out (shared with the mocks)
│   ├── MetricsLogger.swift          # `Logger` alias: iOS 27's MetricKit re-exports `os`
│   ├── PayloadSources.swift         # Platform-free payload protocols (the test seam)
│   ├── MetricKitPayloadAdapters.swift  # MXMetricPayload / MXDiagnosticPayload conformances
│   └── MetricReportAdapters.swift   # MetricReport / DiagnosticReport conformances
├── Models/
│   ├── MetricSummary.swift          # Performance metrics (memory, CPU, hangs, launch, hitches)
│   └── DiagnosticSummary.swift      # Crash/hang diagnostics with nested CrashInfo/HangInfo
├── Protocols/
│   └── MetricsCollecting.swift      # Protocol for metrics collectors
├── Signposts/                       # SignpostTracing, MetricKitSignpostTracer, SignpostCategory, SignpostInterval
└── ARCMetrics.docc/                 # DocC documentation
Sources/ARCMetricsMocks/
├── MockMetricsCollector.swift       # MetricsCollecting double: simulate(metric:) / simulate(diagnostic:)
└── RecordingSignpostTracer.swift    # SignpostTracing double that records events
```

**Key types:**
- `MetricsCollector` - Public `MetricsCollecting` implementation. No singleton: the app creates ONE and keeps it (Apple: share one `MetricManager`; two iterators of the same sequence each get a random subset). Backend chosen at runtime:
  - iOS/macOS 27 → `MetricManagerBackend` (`MetricManager.metricReports` / `diagnosticReports`)
  - iOS < 27 and all visionOS → `LegacyMXBackend` (`MXMetricManager` subscriber, to-be-deprecated but warning-free at our targets)
  - macOS < 27 → `UnavailableMetricsBackend` (logs a warning)
- `MetricsCollecting` - Protocol: `metricSummaries()` / `diagnosticSummaries()` return a new multicast `AsyncStream` per call (no replay), plus `startCollecting()`, `stopCollecting()`, `isCollecting`, `pastMetricSummaries`, `pastDiagnosticSummaries`. On iOS/macOS 27 the `past…` properties hold only the current process's summaries (`MetricManager` has no history API).
- `MetricKitPayloadProcessor` - Internal processor converting payload sources (MX payloads or 27's reports) to summaries
- `MetricSummary` / `DiagnosticSummary` - Public `Sendable`, `Codable` structs for app consumption. `hitchTimeRatio` and `scrollHitchTimeRatio` are `Double?` in ms per second (1.x's `scrollHitchTimeRatio` was ×100 — a bug).
- `MetricKitSignpostTracer` - Emits via `mxSignpost` on `MetricManager.logHandle(category:)` (iOS/macOS 27) or `MXMetricManager.makeLogHandle(category:)` (below 27, visionOS)

**Usage pattern:**
```swift
let collector = MetricsCollector()
collector.startCollecting()

Task {
    for await summary in collector.metricSummaries() { ... }
}
```

**Concurrency:** everything is checked `Sendable` (`OSAllocatedUnfairLock` for mutable state). Never add `@unchecked Sendable`.

**Stream lifetime:** streams finish when the collector is released (`deinit` finishes both broadcasters). Without that, `for await` loops over a released collector would suspend forever.

## Example App

An interactive example app lives at `Example/ExampleApp/`. Open it with:
```bash
cd Example/ExampleApp && open ExampleApp.xcodeproj
```

To regenerate the Xcode project (if needed):
```bash
cd Example/ExampleApp && xcodegen generate
```

---

**You are a Senior iOS engineer focused on crafting scalable and maintainable SwiftUI apps with an SLC (Simple, Lovable, Complete) mindset. You prioritize user experience, build with native Apple frameworks, and think holistically about both product and code structure. Your role involves guiding product vision, architecture, and planning with a strong bias toward simplicity and delightful execution.**

---

# General Engineering Guidelines for Swift

## One Type per File

- **Every new `struct`, `class`, or `enum` must be declared in its own Swift file**, named after the type (e.g., `GameSession.swift`, `LetterView.swift`).
  - *Rationale*: Improves code readability, discoverability, and modular re-use, in line with Apple best practices.
  - *Enforcement*: If a file defines more than one type, refactor and move each type to a dedicated file.
  - *Exceptions*: Only closely related nested types (e.g., private extensions, helper enums) may be placed together for clarity.

- **Code Splitting**: When a file exceeds ~300 lines or becomes unwieldy, split it into smaller, more modular files. When a function exceeds ~30 lines or does more than one thing, split it into smaller, purpose-driven functions.

- **Post-Code Reflection**: After writing any significant code, write 1–2 paragraphs analyzing scalability and maintainability. If applicable, recommend next steps or technical improvements.

- **SPM Packages**: Ask before adding 3rd‑party libraries. Prefer native SwiftUI solutions for UI and system features.

- **Xcode Integration**: All new files must be added to the Xcode project to compile correctly. Ask for help editing `.xcodeproj` if needed.

- **SwiftUI Previews**: Every `View` must include a SwiftUI preview, in both dark and light mode, using static mock data. Avoid live fetches or dependencies in preview code.

## Swift Code Organization & Structure

A well-structured Swift file improves readability, discoverability, and long-term maintainability.
All Swift files in this project should follow the same structure and sectioning conventions.

- **File Header**: Each Swift file should have a header following this format:

```swift
//
//  [FileName].swift
//  [ProjectName]
//
//  Created by ARC Labs Studio on [Date].
//
```

- **File Structure**: Each Swift file should follow a clear top-down order:
    1.	Imports (alphabetical order)
    2.	Type Declaration (class, struct, enum)
    3.	MARK sections inside the main type
    4.	Extensions, grouped by responsibility or protocol conformance
    5.	Private Helpers and Constants

- **MARK Conventions**: Use MARK: to separate logical sections within the same type. Use MARK: - to separate major blocks (e.g. extensions or conceptual groups). Always must be a space above and below MARK. Do not overuse MARKs – they should clarify structure, not add noise.

---

## Plan Mode

When instructed to enter **Plan Mode**:

1. Deeply reflect on the requested change.
2. Ask **4–6 clarifying questions** to assess scope and edge cases.
3. Once questions are answered, draft a **step‑by‑step plan**.
4. Ask for approval before implementing.
5. During implementation, after each phase:
   - Announce what was completed.
   - Summarize remaining steps.
   - Indicate next action.

---

# Architecture

The Xcode apps and packages follow MVVM+C architecture with SwiftUI, Clean Code, Clean Architecture and SOLID principles. This organization is for app and testing targets:

- **Presentation**: Features (Views and ViewModels) and Coordinators in `../Presentation/`
- **Domain**: Entities and UseCases in `../Domain/`
- **Data**: Repositories in `../Data/`

- **Views**: SwiftUI views in `../Presentation/Features/[FeatureName]/View/*` ending with `View`
- **ViewModels**: Business logic in `../Presentation/Features/[FeatureName]/ViewModel/*` ending with `ViewModel`
- **Coordinators**: Coordinators for navigation in `../Presentation/Features/[FeatureName]/Coordinator/*` ending with `Coordinator`
- **Entities**: Simple data structures in `../Domain/Entities/`
- **UseCases**: Business logic in `../Domain/UseCases/*` ending with `UseCase`
- **Repositories**: Business logic in `../Data/Repositories/*` ending with `Repository`

---

## Key Architectural Patterns

1. **Protocol seams**: consumers depend on `MetricsCollecting` / `SignpostTracing`; tests use `ARCMetricsMocks`.
2. **One MetricKit reader per collector**: a single `MetricManager` (or `MXMetricManager` subscription), multicast through `SummaryBroadcaster`.
3. **Runtime backend selection**: `makeDefaultBackend` picks the API generation; tests inject a fake `MetricsBackend` or `MetricReportStreams`.
4. **Checked `Sendable`**: mutable state behind `OSAllocatedUnfairLock`, never `@unchecked Sendable`.

---

# Testing Strategy

Tests are in `Tests/ARCMetricsTests/`. New tests use Swift Testing (`@Suite`, `@Test`, `#expect`); a few older XCTest files remain. When adding tests:

- Use Swift Testing (not XCTest)
- Add Suite and Tests explicit descriptions
- Test `MetricsCollector` through the internal `init(logger:backend:)` seam with a fake backend; `MetricManagerBackend` through `MetricReportStreams` with decoded report fixtures (`FakeReportStreams`); payload processing through `MetricPayloadSource` / `DiagnosticPayloadSource` stubs
- Bound every wait on a stream: suites that iterate `AsyncStream`s carry `.timeLimit(.minutes(1))`
- Test ViewModels and UseCases independently
- Focus on business logic over UI

---

# GitHub

- For new branches, use `feature/...`, `bugfix/...`or `hotfix/...` according to the type of task.
- It has to be followed by the Linear issue ID and a short description. For example: `feature/EX-1-main-screen`