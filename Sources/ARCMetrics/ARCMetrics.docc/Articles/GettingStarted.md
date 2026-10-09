# Getting Started with ARCMetrics

Learn how to integrate ARCMetrics into your app and start collecting performance metrics.

## Overview

ARCMetrics wraps Apple's MetricKit framework to provide simplified access to production performance data. This guide walks you through the integration process and explains what data you'll receive.

## Installation

### Swift Package Manager

Add ARCMetrics to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics", from: "2.1.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Basic Integration

### Step 1: Create a Collector and Start Collecting

Create **one** ``MetricsCollector`` early in your app's lifecycle and keep it for the app's lifetime. Apple recommends a single `MetricManager` per app; the collector reads MetricKit once and multicasts to every consumer.

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

``MetricsCollector/startCollecting()`` is idempotent: a second call while already collecting is ignored.

### Step 2: Consume the Streams

Iterate the streams in a `.task`, which ends the iteration when the view goes away:

```swift
WindowGroup {
    ContentView()
        .task {
            // Performance metrics (memory, CPU, launch time, etc.)
            for await summary in metrics.metricSummaries() {
                await logToAnalytics(summary)
            }
        }
        .task {
            // Diagnostic events (crashes, hangs)
            for await summary in metrics.diagnosticSummaries() where summary.crashCount > 0 {
                await alertCrashReporting(summary)
            }
        }
}
```

Every call to ``MetricsCollecting/metricSummaries()`` or ``MetricsCollecting/diagnosticSummaries()`` creates an independent subscriber that receives every summary delivered from then on. Streams don't replay: for summaries delivered earlier, read ``MetricsCollecting/pastMetricSummaries`` and ``MetricsCollecting/pastDiagnosticSummaries``.

> Note: On iOS and macOS 27 the `past…` properties contain only summaries delivered in the current process, because `MetricManager` has no history API. Below 27 they read MetricKit's on-device history.

### Which MetricKit API Is Used

The collector chooses at runtime:

| Platform | Backend |
|----------|---------|
| iOS 27, macOS 27 | `MetricManager` (requires building with Xcode 27 / Swift 6.4) |
| iOS 17–26, visionOS | `MXMetricManager` subscriber |
| macOS 14–26 | None — logs a warning and delivers nothing |

## Understanding Delivery Timing

MetricKit has specific delivery schedules:

| Report Type | Delivery Frequency | iOS Version |
|-------------|-------------------|-------------|
| Metric Payloads | ~Every 24 hours | iOS 13+ |
| Diagnostic Payloads | Immediately | iOS 15+ |
| Diagnostic Payloads | ~Every 24 hours | iOS 14 |

> Important: Metrics are aggregated over time and delivered asynchronously. You won't receive data immediately after app launch.

## Testing Your Integration

### On Device

For best results, test on a physical device:

1. Install your app via TestFlight or Ad Hoc distribution
2. Use the app normally for at least 24 hours
3. Check for metrics delivery the next day

### Simulated Payloads

Run your app from Xcode **on a physical device**, then choose **Debug → MetricKit → Simulate MetricKit Payloads**. The menu item does not appear when running on the Simulator. Simulated reports contain sample data, not measurements of your app.

## Testing with Dependency Injection

ARCMetrics provides the ``MetricsCollecting`` protocol for dependency injection, and the `ARCMetricsMocks` product provides `MockMetricsCollector` for tests and SwiftUI previews.

### Using the Protocol

Instead of referencing ``MetricsCollector`` directly, depend on the protocol:

```swift
@MainActor
@Observable
final class MetricsViewModel {
    private(set) var latestMetrics: MetricSummary?
    private let collector: any MetricsCollecting

    init(collector: any MetricsCollecting) {
        self.collector = collector
        latestMetrics = collector.pastMetricSummaries.last
    }

    func observeMetrics() async {
        for await summary in collector.metricSummaries() {
            latestMetrics = summary
        }
    }
}
```

The view starts the subscription with `.task { await viewModel.observeMetrics() }`.

### Adding the Mocks Product

Add `ARCMetricsMocks` to your test target (and to the app target if previews use it):

```swift
.testTarget(
    name: "YourAppTests",
    dependencies: [
        .product(name: "ARCMetrics", package: "ARCMetrics"),
        .product(name: "ARCMetricsMocks", package: "ARCMetrics")
    ]
)
```

### Using Mocks in SwiftUI Previews

```swift
#Preview {
    var summary = MetricSummary(timeRange: "Preview Data")
    summary.peakMemoryUsageMB = 150.0
    summary.cumulativeCPUTimeSeconds = 30.0
    summary.foregroundTimeSeconds = 120.0
    summary.cumulativeGPUTimeSeconds = 5.0
    summary.hitchTimeRatio = 2.5

    let mock = MockMetricsCollector(pastMetricSummaries: [summary])
    return MetricsView(viewModel: MetricsViewModel(collector: mock))
}
```

`averageCPUPercentage` is computed from `cumulativeCPUTimeSeconds` and `foregroundTimeSeconds`, so set those instead.

### Writing Unit Tests

`MockMetricsCollector` delivers only what you simulate, to every current subscriber. Streams don't replay, so subscribe before you simulate:

```swift
import ARCMetrics
import ARCMetricsMocks
import Testing

@Test func simulatedMetricIsDelivered() async {
    // Given
    let collector = MockMetricsCollector()
    let metrics = collector.metricSummaries()
    var summary = MetricSummary(timeRange: "Test")
    summary.peakMemoryUsageMB = 100.0

    // When
    collector.simulate(metric: summary)

    // Then
    var iterator = metrics.makeAsyncIterator()
    #expect(await iterator.next()?.peakMemoryUsageMB == 100.0)
}
```

Assert on start/stop with `startCollectingCallCount` and `stopCollectingCallCount`. Unlike the real collector, the mock counts every call, including duplicates.

## Next Steps

- Learn about the data you receive in <doc:UnderstandingMetrics>
- Upgrading from 1.x? Read <doc:MigratingToV2>
- Correlate metrics with Instruments in <doc:InstrumentsIntegration>
- Troubleshoot common issues in <doc:Troubleshooting>
