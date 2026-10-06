# ARCMetrics

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20visionOS%201%2B-blue.svg)
![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)

**Native MetricKit integration for collecting production performance metrics from Apple platform apps.**

MetricKit Integration • Privacy-Preserving • DocC Documentation • Zero External Dependencies

---

## 🎯 Overview

ARCMetrics is a Swift package that provides native MetricKit integration for collecting production performance metrics. It reads Apple's MetricKit — `MetricManager` on iOS/macOS 27, `MXMetricManager` below — and delivers structured `MetricSummary` and `DiagnosticSummary` models through `AsyncStream`s.

Part of the ARC Labs Studio package ecosystem.

### Key Features

- ✅ **Complete MetricKit Integration** - Full support for metric and diagnostic payloads
- ✅ **Async Streams** - `for await` over metric and diagnostic summaries; every subscriber gets every summary
- ✅ **iOS 27 Ready** - Uses Apple's new `MetricManager` on iOS/macOS 27, `MXMetricManager` below
- ✅ **Signpost Tracing** - Measure your own code with `MetricKitSignpostTracer`
- ✅ **Test Doubles** - `ARCMetricsMocks` product with `MockMetricsCollector` and `RecordingSignpostTracer`
- ✅ **Comprehensive DocC Documentation** - Full documentation with guides and tutorials
- ✅ **Production-Ready Monitoring** - Built for real-world production use
- ✅ **Privacy-Preserving** - No PII collected, all data is aggregated and anonymous
- ✅ **Zero External Dependencies** - Only depends on ARCLogger from ARC Labs ecosystem
- ✅ **Instruments Correlation Guide** - Documentation for debugging with Xcode tools

---

## 📋 Requirements

- **Swift:** 6.0+
- **Platforms:** iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- **Xcode:** 16.0+ (Xcode 27 / Swift 6.4 to use `MetricManager` on iOS/macOS 27)

> **Note**: On macOS before 27 the collector delivers nothing (it logs a warning). watchOS and tvOS are not supported.

---

## 🚀 Installation

### Swift Package Manager

#### For Swift Packages

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics.git", from: "2.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "ARCMetrics", package: "ARCMetrics")
    ]
)
```

For tests, also add the mocks product:

```swift
.testTarget(
    name: "YourTargetTests",
    dependencies: [
        .product(name: "ARCMetrics", package: "ARCMetrics"),
        .product(name: "ARCMetricsMocks", package: "ARCMetrics")
    ]
)
```

#### For Xcode Projects

1. **File → Add Package Dependencies**
2. Enter: `https://github.com/arclabs-studio/ARCMetrics`
3. Select version: `2.0.0` or later
4. Add `ARCMetrics` to your target (and `ARCMetricsMocks` to your test target)

---

## 📖 Usage

> **Upgrading from 1.x?** `MetricKitProvider`, its callbacks and `MetricsProviding` were removed in 2.0. See the [migration guide](Sources/ARCMetrics/ARCMetrics.docc/Articles/MigratingToV2.md) and the [CHANGELOG](CHANGELOG.md).

### Quick Start

Create **one** `MetricsCollector` and keep it for the app's lifetime — there is no singleton. Apple recommends a single `MetricManager`; the collector reads MetricKit once and multicasts to every consumer.

```swift
import ARCMetrics

@main
struct MyApp: App {
    private let metrics = MetricsCollector()

    init() {
        metrics.startCollecting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Receiving Metrics

Each call to `metricSummaries()` returns a new, independent stream. Iterate it in a `.task`:

```swift
ContentView()
    .task {
        for await summary in metrics.metricSummaries() {
            print("📊 Peak Memory: \(summary.peakMemoryUsageMB) MB")
            print("⚡️ Avg CPU: \(summary.averageCPUPercentage)%")

            // Send to your backend
            await sendToAnalytics(summary)
        }
    }
```

### Receiving Diagnostics

```swift
ContentView()
    .task {
        for await summary in metrics.diagnosticSummaries() where summary.crashCount > 0 {
            await alertCrashSystem(summary)
        }
    }
```

Streams don't replay. For summaries delivered earlier, read `pastMetricSummaries` / `pastDiagnosticSummaries` — on iOS/macOS 27 they hold only the current process's summaries, because `MetricManager` has no history API.

### Backend Selection

| Platform | MetricKit API used |
|----------|--------------------|
| iOS 27, macOS 27 (built with Xcode 27) | `MetricManager` |
| iOS 17–26, visionOS | `MXMetricManager` subscriber |
| macOS 14–26 | None — logs a warning, delivers nothing |

### Testing

Depend on the `MetricsCollecting` protocol and inject `MockMetricsCollector` from `ARCMetricsMocks`:

```swift
import ARCMetrics
import ARCMetricsMocks
import Testing

@Test func crashIsDelivered() async {
    let collector = MockMetricsCollector()
    let diagnostics = collector.diagnosticSummaries() // subscribe before simulating
    var crash = DiagnosticSummary(timeRange: "Test")
    crash.crashCount = 1

    collector.simulate(diagnostic: crash)

    var iterator = diagnostics.makeAsyncIterator()
    #expect(await iterator.next() == crash)
}
```

`RecordingSignpostTracer` records every `emit` / `begin` / `end` call, so you can assert that instrumented code closes its spans.

### Available Metrics

| Category | Metrics |
|----------|---------|
| **Memory** | Peak & average usage |
| **CPU** | Utilization percentage |
| **Hangs** | UI freeze time |
| **Launches** | Time to first frame |
| **Network** | Cellular & WiFi usage |
| **Crashes** | Detailed crash reports |
| **GPU** | Cumulative GPU time |
| **Disk I/O** | Cumulative logical writes |
| **Animation** | Hitch time ratio, scroll hitch time ratio (ms per second) |

---

## 🏗️ Project Structure

```
ARCMetrics/
├── Package.swift
├── Sources/
│   ├── ARCMetrics/
│   │   ├── MetricsCollector.swift        # Public collector: start/stop, multicast streams
│   │   ├── MetricKitPayloadProcessor.swift  # Transforms payload sources → summary models
│   │   ├── Internal/
│   │   │   ├── DefaultMetricsBackend.swift   # Runtime backend selection
│   │   │   ├── MetricManagerBackend.swift    # iOS/macOS 27 MetricManager
│   │   │   ├── LegacyMXBackend.swift         # MXMetricManager subscriber
│   │   │   ├── MetricsBackend.swift          # Backend protocol + macOS < 27 no-op
│   │   │   ├── SummaryBroadcaster.swift      # AsyncStream fan-out
│   │   │   ├── PayloadSources.swift          # Platform-free payload protocols (the seam)
│   │   │   ├── MetricKitPayloadAdapters.swift  # MXPayload conformances (iOS/visionOS)
│   │   │   └── MetricReportAdapters.swift    # MetricReport conformances (iOS/macOS 27)
│   │   ├── Models/
│   │   │   ├── MetricSummary.swift       # Performance metrics model
│   │   │   └── DiagnosticSummary.swift   # Crash/hang diagnostics model
│   │   ├── Protocols/
│   │   │   └── MetricsCollecting.swift   # Protocol for metrics collectors
│   │   ├── Signposts/                    # SignpostTracing, MetricKitSignpostTracer, …
│   │   └── ARCMetrics.docc/              # DocC documentation
│   └── ARCMetricsMocks/
│       ├── MockMetricsCollector.swift    # MetricsCollecting test double
│       └── RecordingSignpostTracer.swift # SignpostTracing test double
├── Tests/
│   └── ARCMetricsTests/
└── Example/
    └── ExampleApp/                       # Interactive demo app
```

---

## 🧪 Testing

```bash
swift test
```

### Coverage

- **Target:** 100% (packages)
- **Minimum:** 80%

---

## 📐 Architecture

ARCMetrics follows a simple architecture optimized for MetricKit integration:

- **MetricsCollector** - One instance per app; picks the MetricKit backend at runtime and multicasts summaries to every `AsyncStream` subscriber
- **Backends** - `MetricManager` (iOS/macOS 27), `MXMetricManager` subscriber (iOS < 27, visionOS), no-op (macOS < 27)
- **MetricKitPayloadProcessor** - Internal processor that transforms raw MetricKit reports
- **Models** - `Sendable` structs for thread-safe metric data
- Everything is checked `Sendable` — no `@unchecked Sendable`

For complete architecture guidelines, see [ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge).

---

## 📚 Documentation

Full DocC documentation is included with guides for:

- **Getting Started** - Quick integration guide
- **Migrating to ARCMetrics 2.0** - Upgrade from the 1.x callback API
- **Understanding Metrics** - Interpret your data
- **Instruments Integration** - Debug with Xcode tools
- **Architecture** - Components and data flow
- **Troubleshooting** - Common issues & FAQ

Build documentation:

```bash
swift package generate-documentation
```

---

## 🎮 Example App

Want to see ARCMetrics in action? Check out the **interactive example app**!

```bash
cd Example/ExampleApp
open ExampleApp.xcodeproj
```

[**View Example README →**](Example/README.md)

**Features:**
- 📊 Dashboard with live metrics
- 📝 Detailed metrics history
- 🔨 Performance simulators (memory, CPU, hangs)
- ⚙️ Settings and configuration
- 📖 Interactive learning experience

---

## ⚠️ Important Notes

- Metrics are delivered **every ~24 hours** (not real-time)
- Works best on **physical devices** (limited in Simulator)
- **Simulate payloads** with Xcode → Debug → MetricKit → Simulate MetricKit Payloads — only when running on a physical device; the reports contain sample data
- **TestFlight/Production** recommended for testing
- Data is **aggregated and anonymous**

---

## 🤝 Contributing

This is an internal package for ARC Labs Studio. Team members:

1. Create a feature branch: `feature/ARC-123-description`
2. Follow [ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge) standards
3. Ensure tests pass: `swift test`
4. Run quality checks: `make lint && make fix`
5. Create a pull request to `develop`

### Commit Messages

Follow [Conventional Commits](https://github.com/arclabs-studio/ARCKnowledge/blob/main/Workflow/git-commits.md):

```
feat(ARC-123): add new metric type support
fix(ARC-456): resolve crash on payload processing
docs: update installation instructions
```

---

## 📦 Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** - Breaking changes
- **MINOR** - New features (backwards compatible)
- **PATCH** - Bug fixes (backwards compatible)

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## 📄 License

**PolyForm Noncommercial License 1.0.0** © 2025–2026 ARC Labs Studio.

Source-available. Free for non-commercial use (research, study, hobby, evaluation). **Commercial use requires a separate license** — contact `arclabs.studio@gmail.com`.

ARC Labs Studio's own commercial products are covered by an internal use grant — see [INTERNAL-USE.md](INTERNAL-USE.md).

See [LICENSE](LICENSE) for the full license text.

---

## 🔗 Related Resources

- **[ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge)** - Development standards and guidelines
- **[ARCDevTools](https://github.com/arclabs-studio/ARCDevTools)** - Quality tooling and automation
- **[ARCLogger](https://github.com/arclabs-studio/ARCLogger)** - Logging system
- **[ARCFirebase](https://github.com/arclabs-studio/ARCFirebase)** - Firebase integration

---

<div align="center">

Made with 💛 by ARC Labs Studio

[**GitHub**](https://github.com/arclabs-studio) • [**Issues**](https://github.com/arclabs-studio/ARCMetrics/issues)

</div>
