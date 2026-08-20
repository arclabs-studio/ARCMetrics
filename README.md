# ARCMetrics

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20visionOS%201%2B-blue.svg)
![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)

**Native MetricKit integration for collecting production performance metrics from Apple platform apps.**

MetricKit Integration • Privacy-Preserving • DocC Documentation • Zero External Dependencies

---

## 🎯 Overview

ARCMetrics is a Swift package that provides native MetricKit integration for collecting production performance metrics. It simplifies the process of subscribing to and processing MetricKit payloads, delivering structured `MetricSummary` and `DiagnosticSummary` models via callbacks.

Part of the ARC Labs Studio package ecosystem.

### Key Features

- ✅ **Complete MetricKit Integration** - Full support for metric and diagnostic payloads
- ✅ **Simplified API** - Easy-to-use callbacks for receiving metrics
- ✅ **Comprehensive DocC Documentation** - Full documentation with guides and tutorials
- ✅ **Production-Ready Monitoring** - Built for real-world production use
- ✅ **Privacy-Preserving** - No PII collected, all data is aggregated and anonymous
- ✅ **Zero External Dependencies** - Only depends on ARCLogger from ARC Labs ecosystem
- ✅ **Instruments Correlation Guide** - Documentation for debugging with Xcode tools

---

## 📋 Requirements

- **Swift:** 6.0+
- **Platforms:** iOS 17.0+ / visionOS 1.0+
- **Xcode:** 16.0+

> **Note**: MetricKit is not available on macOS, watchOS, or tvOS.

---

## 🚀 Installation

### Swift Package Manager

#### For Swift Packages

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics.git", from: "1.0.0")
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

#### For Xcode Projects

1. **File → Add Package Dependencies**
2. Enter: `https://github.com/arclabs-studio/ARCMetrics`
3. Select version: `1.0.0` or later
4. Add `ARCMetrics` to your target

---

## 📖 Usage

### Quick Start

```swift
import ARCMetrics

@main
struct MyApp: App {
    init() {
        MetricKitProvider.shared.startCollecting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Handling Metric Payloads

```swift
// Register callbacks for receiving metrics
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        print("📊 Peak Memory: \(summary.peakMemoryUsageMB) MB")
        print("⚡️ Avg CPU: \(summary.averageCPUPercentage)%")

        // Send to your backend
        sendToAnalytics(summary)
    }
}
```

### Handling Diagnostic Payloads

```swift
MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    for summary in summaries {
        if summary.crashCount > 0 {
            alertCrashSystem(summary)
        }
    }
}
```

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
| **Animation** | Scroll hitch time ratio |

---

## 🏗️ Project Structure

```
ARCMetrics/
├── Package.swift
├── Sources/
│   └── ARCMetrics/
│       ├── MetricKitProvider.swift       # Singleton, subscribes to MXMetricManager
│       ├── MetricKitPayloadProcessor.swift  # Transforms payload sources → summary models
│       ├── Internal/
│       │   ├── PayloadSources.swift      # Platform-free payload protocols (the seam)
│       │   └── MetricKitPayloadAdapters.swift  # MXPayload conformances (iOS/visionOS)
│       ├── Models/
│       │   ├── MetricSummary.swift       # Performance metrics model
│       │   └── DiagnosticSummary.swift   # Crash/hang diagnostics model
│       ├── Protocols/
│       │   └── MetricsProviding.swift    # Protocol for metrics provider
│       └── ARCMetrics.docc/              # DocC documentation
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

- **MetricKitProvider** - Singleton that manages MXMetricManager subscription
- **MetricKitPayloadProcessor** - Internal processor that transforms raw MetricKit payloads
- **Models** - `Sendable` structs for thread-safe metric data

For complete architecture guidelines, see [ARCKnowledge](https://github.com/arclabs-studio/ARCKnowledge).

---

## 📚 Documentation

Full DocC documentation is included with guides for:

- **Getting Started** - Quick integration guide
- **Understanding Metrics** - Interpret your data
- **Instruments Integration** - Debug with Xcode tools
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
