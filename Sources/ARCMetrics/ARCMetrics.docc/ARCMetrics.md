# ``ARCMetrics``

Native MetricKit integration for collecting production performance metrics from Apple platform apps.

## Overview

ARCMetrics provides a simplified interface to Apple's MetricKit framework, enabling you to collect and analyze performance metrics and diagnostics from your production apps.

MetricKit delivers aggregated reports approximately every 24 hours containing metrics about memory usage, CPU utilization, launch times, hangs, animation hitches, and network activity. Diagnostic reports for crashes, hangs, and resource exceptions are delivered immediately rather than daily (iOS 15 and later).

``MetricsCollector`` uses the newest MetricKit API the device offers: Apple's `MetricManager` on iOS and macOS 27, and the `MXMetricManager` subscriber on earlier iOS and on visionOS. On macOS before 27 it delivers nothing and logs a warning.

> Note: Upgrading from 1.x? `MetricKitProvider` and `MetricsProviding` are gone. See <doc:MigratingToV2>.

### Key Features

- **Async Streams**: ``MetricsCollecting/metricSummaries()`` and ``MetricsCollecting/diagnosticSummaries()`` return `AsyncStream`s; every call is an independent subscriber, so several consumers never steal summaries from each other
- **Comprehensive Metrics**: Memory, CPU, GPU, launch time, hangs, disk I/O, animation hitches, and network usage
- **Diagnostic Reports**: Crash and hang information with detailed context
- **Signpost Tracing**: Measure your own code with ``MetricKitSignpostTracer``, aggregated by MetricKit and visible in Instruments
- **Tracing with Attributes**: ``Tracing`` adds attributes, parent links and outcomes; ``TeeTracer`` feeds MetricKit and another backend, such as ARCMetricsOTel, with the same spans
- **Privacy-Preserving**: No personally identifiable information collected
- **Production-Ready**: Designed for real-world app monitoring
- **Testable**: Inject the ``MetricsCollecting`` protocol; the `ARCMetricsMocks` product provides `MockMetricsCollector`, `RecordingSignpostTracer` and `RecordingTracer`

### Quick Start

Create **one** collector and keep it for the app's lifetime, then consume its streams:

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
                .task {
                    for await summary in metrics.metricSummaries() {
                        print("Peak Memory: \(summary.peakMemoryUsageMB) MB")
                        print("Avg CPU: \(summary.averageCPUPercentage)%")
                        print("GPU Time: \(summary.cumulativeGPUTimeSeconds)s")
                        print("Disk Writes: \(summary.cumulativeDiskWritesMB) MB")
                        if let hitches = summary.hitchTimeRatio {
                            print("Hitch Time: \(hitches) ms/s")
                        }
                    }
                }
                .task {
                    for await summary in metrics.diagnosticSummaries() where summary.crashCount > 0 {
                        // Alert your crash reporting system
                    }
                }
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:MigratingToV2>
- ``MetricsCollector``
- ``MetricsCollecting``

### Understanding Your Data

- <doc:UnderstandingMetrics>
- ``MetricSummary``
- ``DiagnosticSummary``

### Signpost Tracing

- ``SignpostTracing``
- ``MetricKitSignpostTracer``
- ``SignpostCategory``
- ``SignpostInterval``
- ``NoOpSignpostTracer``

### Tracing with Attributes

- <doc:TracingWithAttributes>
- ``Tracing``
- ``TraceSpan``
- ``TraceOutcome``
- ``TraceAttributeValue``
- ``TraceAttributes``
- ``TeeTracer``
- ``NoOpTracer``

### Architecture

- <doc:Architecture>

### Advanced Topics

- <doc:InstrumentsIntegration>
- <doc:Troubleshooting>
