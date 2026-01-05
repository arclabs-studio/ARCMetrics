# Getting Started with ARCMetricsKit

Learn how to integrate MetricKit into your app and start collecting performance metrics.

## Overview

ARCMetricsKit makes it simple to collect production metrics from your app. This guide will walk you through the basic setup and show you how to access metric data.

## Installation

### Swift Package Manager

Add ARCMetricsKit to your project dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/arclabs/ARCMetrics.git", from: "1.0.0")
]
```

## Basic Setup

### 1. Start Collecting Metrics

Initialize MetricKit early in your app's lifecycle:

```swift
import SwiftUI
import ARCMetricsKit

@main
struct MyApp: App {
    init() {
        // Start MetricKit collection
        MetricKitProvider.shared.startCollecting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Register Callbacks (Optional)

To receive metric data, register callbacks:

```swift
// Receive performance metrics
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        print("📊 Peak Memory: \(summary.peakMemoryUsageMB) MB")
        print("⚡️ Avg CPU: \(summary.averageCPUPercentage)%")
        print("🐌 Hang Time: \(summary.totalHangTimeSeconds)s")

        // Send to your analytics backend
        sendToBackend(summary)
    }
}

// Receive diagnostic events (crashes, hangs)
MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    for summary in summaries {
        if summary.crashCount > 0 {
            print("💥 Crashes detected: \(summary.crashCount)")
            alertCrashReportingSystem(summary)
        }
    }
}
```

## Understanding MetricKit Delivery

### When Will I Receive Metrics?

MetricKit delivers payloads **approximately every 24 hours**. Here's what you need to know:

- **Not immediate**: Metrics are not available right after app launch
- **Background collection**: Apple collects metrics while your app runs
- **Batch delivery**: Data is aggregated and delivered once per day
- **Development delays**: In debug builds, payloads may take 2-3 days to appear

### What Data Do I Receive?

Each payload contains:
- Aggregated metrics from the past 24 hours
- Data from real usage (not just your device)
- Anonymous, privacy-preserving information

## Next Steps

- Learn how to interpret your metrics: <doc:UnderstandingMetrics>
- Correlate with Instruments: <doc:InstrumentsIntegration>
- Common issues: <doc:TroubleshootingAndFAQ>
