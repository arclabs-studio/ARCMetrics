# ``ARCMetricsKit``

Native MetricKit integration for collecting production performance metrics from Apple platform apps.

## Overview

ARCMetricsKit provides a simplified interface to Apple's MetricKit framework, enabling you to collect and analyze performance metrics and diagnostics from your production apps.

MetricKit delivers aggregated reports approximately every 24 hours containing metrics about memory usage, CPU utilization, launch times, hangs, and network activity. Diagnostic reports for crashes and hangs are delivered immediately in iOS 15+ and macOS 12+.

![ARCMetricsKit Banner](arcmetrics-banner)

### Key Features

- **Simplified API**: Easy-to-use callbacks for receiving metrics and diagnostics
- **Comprehensive Metrics**: Memory, CPU, GPU, launch time, hangs, disk I/O, animation, and network usage
- **Diagnostic Reports**: Crash and hang information with detailed context
- **Privacy-Preserving**: No personally identifiable information collected
- **Production-Ready**: Designed for real-world app monitoring
- **Testable**: Includes `MetricsProviding` protocol for dependency injection and testing

### Quick Start

```swift
import ARCMetricsKit

@main
struct MyApp: App {
    init() {
        // Start collecting metrics
        MetricKitProvider.shared.startCollecting()

        // Register callback for performance metrics
        MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
            for summary in summaries {
                print("Peak Memory: \(summary.peakMemoryUsageMB) MB")
                print("Avg CPU: \(summary.averageCPUPercentage)%")
                print("GPU Time: \(summary.cumulativeGPUTimeSeconds)s")
                print("Disk Writes: \(summary.cumulativeDiskWritesMB) MB")
                print("Scroll Hitch: \(summary.scrollHitchTimeRatio)%")
            }
        }

        // Register callback for diagnostics
        MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
            for summary in summaries {
                if summary.crashCount > 0 {
                    // Alert your crash reporting system
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``MetricKitProvider``
- ``MetricsProviding``

### Understanding Your Data

- <doc:UnderstandingMetrics>
- ``MetricSummary``
- ``DiagnosticSummary``

### Architecture

- <doc:Architecture>

### Advanced Topics

- <doc:InstrumentsIntegration>
- <doc:Troubleshooting>
