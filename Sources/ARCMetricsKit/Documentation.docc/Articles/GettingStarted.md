# Getting Started with ARCMetricsKit

Learn how to integrate ARCMetricsKit into your app and start collecting performance metrics.

## Overview

ARCMetricsKit wraps Apple's MetricKit framework to provide simplified access to production performance data. This guide walks you through the integration process and explains what data you'll receive.

## Installation

### Swift Package Manager

Add ARCMetricsKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Basic Integration

### Step 1: Start Collecting Metrics

Initialize the MetricKit provider early in your app's lifecycle:

```swift
import ARCMetricsKit

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

### Step 2: Register Callbacks

Set up callbacks to receive metrics when they arrive:

```swift
// Performance metrics (memory, CPU, launch time, etc.)
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        // Process each MetricSummary
        logToAnalytics(summary)
    }
}

// Diagnostic events (crashes, hangs)
MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    for summary in summaries {
        if summary.crashCount > 0 {
            alertCrashReporting(summary)
        }
    }
}
```

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

### In Simulator

The Simulator provides limited MetricKit support. Use Xcode's **Debug → Simulate MetricKit Payload** for testing.

## Testing with Dependency Injection

ARCMetricsKit provides the ``MetricsProviding`` protocol for dependency injection, enabling you to write testable code and provide mock data for SwiftUI previews.

### Using the Protocol

Instead of referencing ``MetricKitProvider`` directly, depend on the protocol:

```swift
class MetricsViewModel: ObservableObject {
    private let metricsProvider: MetricsProviding

    init(metricsProvider: MetricsProviding = MetricKitProvider.shared) {
        self.metricsProvider = metricsProvider
        setupCallbacks()
    }

    private func setupCallbacks() {
        metricsProvider.onMetricPayloadsReceived = { [weak self] summaries in
            // Handle metrics
        }
    }
}
```

### Creating a Mock for Tests

Create a simple mock that conforms to `MetricsProviding`:

```swift
final class MockMetricsProvider: MetricsProviding, @unchecked Sendable {
    var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)?
    var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)?
    var pastMetricSummaries: [MetricSummary] = []
    var pastDiagnosticSummaries: [DiagnosticSummary] = []

    func startCollecting() { }
    func stopCollecting() { }

    // Test helper
    func simulateMetricPayload(_ summary: MetricSummary) {
        pastMetricSummaries.append(summary)
        onMetricPayloadsReceived?([summary])
    }
}
```

### Using Mocks in SwiftUI Previews

```swift
#Preview {
    let mock = MockMetricsProvider()

    // Create sample data
    var summary = MetricSummary(timeRange: "Preview Data")
    summary.peakMemoryUsageMB = 150.0
    summary.averageCPUPercentage = 25.0
    summary.cumulativeGPUTimeSeconds = 5.0
    summary.scrollHitchTimeRatio = 2.5

    mock.pastMetricSummaries = [summary]

    return MetricsView(viewModel: MetricsViewModel(metricsProvider: mock))
}
```

### Writing Unit Tests

```swift
func testMetricCallback() {
    let mock = MockMetricsProvider()
    let viewModel = MetricsViewModel(metricsProvider: mock)
    var summary = MetricSummary(timeRange: "Test")
    summary.peakMemoryUsageMB = 100.0

    mock.simulateMetricPayload(summary)

    XCTAssertEqual(viewModel.latestMetrics?.peakMemoryUsageMB, 100.0)
}
```

## Next Steps

- Learn about the data you receive in <doc:UnderstandingMetrics>
- Correlate metrics with Instruments in <doc:InstrumentsIntegration>
- Troubleshoot common issues in <doc:Troubleshooting>
