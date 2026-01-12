# Architecture

Understand the internal architecture and data flow of ARCMetricsKit.

## Overview

ARCMetricsKit provides a clean abstraction layer over Apple's MetricKit framework. This guide explains the key components, their responsibilities, and how data flows through the system.

## Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Your App                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐                                              │
│  │   App/Scene      │                                              │
│  │   Initialization │──┐                                           │
│  └──────────────────┘  │                                           │
│                        │ startCollecting()                         │
│                        ▼                                           │
│  ┌────────────────────────────────────────┐                        │
│  │         MetricsProviding               │◄── Protocol            │
│  │  (MetricKitProvider or Mock)           │                        │
│  └───────────────┬────────────────────────┘                        │
│                  │                                                  │
│                  │ onMetricPayloadsReceived                        │
│                  │ onDiagnosticPayloadsReceived                    │
│                  ▼                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                      │
│  │   ViewModel      │───▶│   Analytics/     │                      │
│  │   or Handler     │    │   Backend        │                      │
│  └──────────────────┘    └──────────────────┘                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                       ARCMetricsKit                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────┐       │
│  │              MetricKitProvider (Singleton)               │       │
│  │                                                          │       │
│  │  • Subscribes to MXMetricManager                        │       │
│  │  • Implements MXMetricManagerSubscriber                 │       │
│  │  • Stores pastMetricSummaries/pastDiagnosticSummaries   │       │
│  │  • Thread-safe with @unchecked Sendable                 │       │
│  └──────────────────────────┬──────────────────────────────┘       │
│                             │                                       │
│                             │ Raw MX payloads                       │
│                             ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐       │
│  │           MetricKitPayloadProcessor (Internal)          │       │
│  │                                                          │       │
│  │  • Transforms MXMetricPayload → MetricSummary           │       │
│  │  • Transforms MXDiagnosticPayload → DiagnosticSummary   │       │
│  │  • Extracts relevant fields from MX types               │       │
│  └──────────────────────────┬──────────────────────────────┘       │
│                             │                                       │
│                             │ Simplified models                     │
│                             ▼                                       │
│  ┌────────────────────┐    ┌────────────────────┐                  │
│  │   MetricSummary    │    │  DiagnosticSummary │                  │
│  │                    │    │                    │                  │
│  │  • Memory metrics  │    │  • Crash info      │                  │
│  │  • CPU metrics     │    │  • Hang info       │                  │
│  │  • GPU metrics     │    │  • Exception counts│                  │
│  │  • Disk I/O        │    │                    │                  │
│  │  • Animation       │    │                    │                  │
│  │  • Network         │    │                    │                  │
│  │  • Launch time     │    │                    │                  │
│  └────────────────────┘    └────────────────────┘                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Apple MetricKit Framework                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  MXMetricManager ──▶ MXMetricPayload                               │
│                  ──▶ MXDiagnosticPayload                           │
│                                                                     │
│  Delivers payloads ~every 24 hours (metrics)                       │
│  Delivers immediately (diagnostics on iOS 15+)                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Types

### MetricsProviding Protocol

The ``MetricsProviding`` protocol defines the contract for metrics providers:

```swift
public protocol MetricsProviding: AnyObject, Sendable {
    var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)? { get set }
    var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)? { get set }

    func startCollecting()
    func stopCollecting()

    var pastMetricSummaries: [MetricSummary] { get }
    var pastDiagnosticSummaries: [DiagnosticSummary] { get }
}
```

This protocol enables:
- **Dependency injection**: Pass providers to ViewModels and services
- **Testing**: Create mock providers for unit tests
- **SwiftUI previews**: Provide sample data without MetricKit

### MetricKitProvider

``MetricKitProvider`` is the production implementation:

- **Singleton pattern**: Access via `MetricKitProvider.shared`
- **MXMetricManagerSubscriber**: Receives raw MetricKit payloads
- **Thread-safe**: Marked `@unchecked Sendable` with internal synchronization
- **Historical data**: Stores received summaries in `pastMetricSummaries` and `pastDiagnosticSummaries`

### MetricSummary

``MetricSummary`` aggregates performance metrics into a simple, `Codable` struct:

| Category | Properties |
|----------|------------|
| Memory | `peakMemoryUsageMB`, `averageMemoryUsageMB` |
| CPU | `cumulativeCPUTimeSeconds`, `averageCPUPercentage` |
| GPU | `cumulativeGPUTimeSeconds` |
| Disk | `cumulativeDiskWritesMB` |
| Animation | `scrollHitchTimeRatio` |
| Responsiveness | `totalHangTimeSeconds`, `averageLaunchTimeSeconds` |
| Time | `foregroundTimeSeconds`, `backgroundTimeSeconds` |
| Network | `cellularDownloadMB`, `cellularUploadMB`, `wifiDownloadMB`, `wifiUploadMB` |

### DiagnosticSummary

``DiagnosticSummary`` contains diagnostic events:

- **Crashes**: Count and detailed `CrashInfo` with exception type, signal, termination reason
- **Hangs**: Count and detailed `HangInfo` with duration
- **Exceptions**: `diskWriteExceptionCount`, `cpuExceptionCount`

## Data Flow

1. **Subscription**: When `startCollecting()` is called, `MetricKitProvider` registers with `MXMetricManager`

2. **Delivery**: MetricKit delivers payloads to the `MXMetricManagerSubscriber` delegate methods

3. **Transformation**: `MetricKitPayloadProcessor` extracts relevant data and creates simplified models

4. **Callbacks**: Callbacks are invoked with the transformed summaries

5. **Storage**: Summaries are stored in `pastMetricSummaries`/`pastDiagnosticSummaries` for later access

## Thread Safety

ARCMetricsKit is designed for Swift 6 strict concurrency:

- All public types conform to `Sendable`
- Callbacks are marked `@Sendable`
- Internal state is protected against data races
- Callbacks may be invoked on background threads—dispatch to `@MainActor` for UI updates

```swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    Task { @MainActor in
        self.updateUI(with: summaries)
    }
}
```

## Testing Architecture

For testing, create a mock that conforms to `MetricsProviding`:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Test Environment                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐                                              │
│  │   XCTestCase     │                                              │
│  └────────┬─────────┘                                              │
│           │                                                         │
│           │ injects                                                 │
│           ▼                                                         │
│  ┌────────────────────────────────────────┐                        │
│  │         MockMetricsProvider            │                        │
│  │                                        │                        │
│  │  • simulateMetricPayload()            │                        │
│  │  • simulateDiagnosticPayload()        │                        │
│  │  • Tracks call counts                 │                        │
│  │  • Stores simulated data              │                        │
│  └────────────────────────────────────────┘                        │
│           │                                                         │
│           │ conforms to                                             │
│           ▼                                                         │
│  ┌────────────────────────────────────────┐                        │
│  │         MetricsProviding               │                        │
│  └────────────────────────────────────────┘                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## See Also

- ``MetricsProviding``
- ``MetricKitProvider``
- ``MetricSummary``
- ``DiagnosticSummary``
- <doc:GettingStarted>
