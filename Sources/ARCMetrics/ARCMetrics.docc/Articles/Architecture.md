# Architecture

Understand the internal architecture and data flow of ARCMetrics.

## Overview

ARCMetrics provides a clean abstraction layer over Apple's MetricKit framework. This guide explains the key components, their responsibilities, and how data flows through the system.

## Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Your App                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐                                               │
│  │ Composition Root │  creates ONE collector, startCollecting()     │
│  └────────┬─────────┘                                               │
│           │ injects                                                 │
│           ▼                                                         │
│  ┌────────────────────────────────────────┐                         │
│  │         MetricsCollecting              │◄── Protocol             │
│  │  (MetricsCollector or Mock)            │                         │
│  └───────────────┬────────────────────────┘                         │
│                  │                                                  │
│                  │ metricSummaries()      ─ one AsyncStream         │
│                  │ diagnosticSummaries()    per subscriber          │
│                  ▼                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                       │
│  │   ViewModel      │    │   Analytics/     │                       │
│  │   (for await)    │    │   Backend        │                       │
│  └──────────────────┘    └──────────────────┘                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          ARCMetrics                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │                  MetricsCollector                       │        │
│  │                                                         │        │
│  │  • Owns start/stop state (idempotent)                   │        │
│  │  • Multicasts each summary to every stream subscriber   │        │
│  │  • Picks a backend at runtime                           │        │
│  └──────────────────────────┬──────────────────────────────┘        │
│                             │                                       │
│              ┌──────────────┼───────────────────┐                   │
│              ▼              ▼                   ▼                   │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐     │
│  │ MetricManager    │ │ MXMetricManager  │ │ Unavailable      │     │
│  │ backend          │ │ subscriber       │ │ (macOS < 27)     │     │
│  │ iOS/macOS 27     │ │ iOS < 27,visionOS│ │ logs a warning   │     │
│  └────────┬─────────┘ └────────┬─────────┘ └──────────────────┘     │
│           │ MetricReport       │ MXMetricPayload                    │
│           │ DiagnosticReport   │ MXDiagnosticPayload                │
│           ▼                    ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │           MetricKitPayloadProcessor (Internal)          │        │
│  │                                                         │        │
│  │  • Reads platform-free payload-source protocols         │        │
│  │  • Units normalized at the adapters (MB, s, ms/s)       │        │
│  │  • Builds MetricSummary / DiagnosticSummary             │        │
│  └──────────────────────────┬──────────────────────────────┘        │
│                             │                                       │
│                             │ Simplified models                     │
│                             ▼                                       │
│  ┌────────────────────┐    ┌────────────────────┐                   │
│  │   MetricSummary    │    │  DiagnosticSummary │                   │
│  │                    │    │                    │                   │
│  │  • Memory metrics  │    │  • Crash info      │                   │
│  │  • CPU metrics     │    │  • Hang info       │                   │
│  │  • GPU metrics     │    │  • Exception counts│                   │
│  │  • Disk I/O        │    │                    │                   │
│  │  • Animation       │    │                    │                   │
│  │  • Network         │    │                    │                   │
│  │  • Launch time     │    │                    │                   │
│  └────────────────────┘    └────────────────────┘                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     Apple MetricKit Framework                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  iOS/macOS 27:  MetricManager ──▶ metricReports (async sequence)    │
│                               ──▶ diagnosticReports                 │
│  Earlier:       MXMetricManager ──▶ MXMetricPayload                 │
│                                 ──▶ MXDiagnosticPayload             │
│                                                                     │
│  Delivers metrics ~every 24 hours                                   │
│  Delivers diagnostics immediately (iOS 15+)                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Types

### MetricsCollecting Protocol

The ``MetricsCollecting`` protocol defines the contract for metrics collectors:

```swift
public protocol MetricsCollecting: Sendable {
    func metricSummaries() -> AsyncStream<MetricSummary>
    func diagnosticSummaries() -> AsyncStream<DiagnosticSummary>

    func startCollecting()
    func stopCollecting()
    var isCollecting: Bool { get }

    var pastMetricSummaries: [MetricSummary] { get }
    var pastDiagnosticSummaries: [DiagnosticSummary] { get }
}
```

This protocol enables:
- **Dependency injection**: Pass collectors to ViewModels and services
- **Testing**: Inject `MockMetricsCollector` from the `ARCMetricsMocks` product
- **SwiftUI previews**: Provide sample data without MetricKit

Every call to ``MetricsCollecting/metricSummaries()`` or ``MetricsCollecting/diagnosticSummaries()`` returns a new, independent stream that receives every summary delivered after the call. There is no replay; history comes from the `past…` properties.

### MetricsCollector

``MetricsCollector`` is the production implementation:

- **One instance per app**: Created with ``MetricsCollector/init(logger:)`` and kept by the app. There is no singleton. Apple recommends a single `MetricManager`, because two tasks iterating the same report sequence each receive a non-deterministic subset of reports — so the collector reads each sequence exactly once and multicasts.
- **Runtime backend selection**:
  - iOS 27 / macOS 27: `MetricManager`'s `metricReports` and `diagnosticReports` async sequences. Compiled only with the Swift 6.4 toolchain (Xcode 27), because older SDKs do not contain `MetricManager`.
  - iOS below 27 and all visionOS: an `MXMetricManager` subscriber. Apple marks `MXMetricManager` to-be-deprecated; it still works and raises no warning at this package's deployment targets.
  - macOS below 27: none. `startCollecting()` logs a warning and nothing is delivered.
- **Thread-safe**: Checked `Sendable`. Mutable state lives behind locks; there is no `@unchecked Sendable`.
- **Historical data**: `pastMetricSummaries` / `pastDiagnosticSummaries` read MetricKit's on-device history below 27. On iOS / macOS 27 they hold only summaries delivered in the current process, because `MetricManager` has no history API.

### MetricSummary

``MetricSummary`` aggregates performance metrics into a simple, `Codable` struct:

| Category | Properties |
|----------|------------|
| Memory | `peakMemoryUsageMB`, `averageMemoryUsageMB` |
| CPU | `cumulativeCPUTimeSeconds`, `averageCPUPercentage` |
| GPU | `cumulativeGPUTimeSeconds` |
| Disk | `cumulativeDiskWritesMB` |
| Animation | `hitchTimeRatio`, `scrollHitchTimeRatio` (both `Double?`, ms per second) |
| Responsiveness | `totalHangTimeSeconds`, `averageLaunchTimeSeconds` |
| Time | `foregroundTimeSeconds`, `backgroundTimeSeconds` |
| Network | `cellularDownloadMB`, `cellularUploadMB`, `wifiDownloadMB`, `wifiUploadMB` |

### DiagnosticSummary

``DiagnosticSummary`` contains diagnostic events:

- **Crashes**: Count and detailed `CrashInfo` with exception type, signal, termination reason
- **Hangs**: Count and detailed `HangInfo` with duration
- **Exceptions**: `diskWriteExceptionCount`, `cpuExceptionCount`

On iOS / macOS 27 each `DiagnosticReport` is a single event, so each summary holds exactly one crash, one hang, or one exception. App-launch and memory-exception diagnostics produce no summary.

## Data Flow

1. **Subscription**: When `startCollecting()` is called, `MetricsCollector` starts its backend — iterating `MetricManager`'s report sequences on 27, or registering with `MXMetricManager` below it

2. **Delivery**: MetricKit delivers reports to the backend

3. **Transformation**: `MetricKitPayloadProcessor` extracts relevant data and creates simplified models

4. **Fan-out**: Each summary is yielded to every open `metricSummaries()` / `diagnosticSummaries()` stream

5. **History**: Summaries are available from `pastMetricSummaries`/`pastDiagnosticSummaries` (see the platform note above)

## Thread Safety

ARCMetrics is designed for Swift 6 strict concurrency:

- All public types conform to `Sendable`, with checked conformances only
- Summaries arrive through `AsyncStream`, so you choose the isolation by choosing where you iterate
- Internal state is protected by locks; nothing is called while a lock is held

Iterate on the main actor to update UI directly — no hop needed:

```swift
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var summaries: [MetricSummary] = []
    private let collector: any MetricsCollecting

    init(collector: any MetricsCollecting) {
        self.collector = collector
    }

    func observe() async {
        for await summary in collector.metricSummaries() {
            summaries.append(summary)
        }
    }
}
```

## Testing Architecture

For testing, inject `MockMetricsCollector` from the `ARCMetricsMocks` product:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Test Environment                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐                                               │
│  │   @Test          │                                               │
│  └────────┬─────────┘                                               │
│           │                                                         │
│           │ injects                                                 │
│           ▼                                                         │
│  ┌────────────────────────────────────────┐                         │
│  │         MockMetricsCollector           │                         │
│  │                                        │                         │
│  │  • simulate(metric:)                   │                         │
│  │  • simulate(diagnostic:)               │                         │
│  │  • Tracks start/stop call counts       │                         │
│  │  • Fixed past summaries via init       │                         │
│  └────────────────────────────────────────┘                         │
│           │                                                         │
│           │ conforms to                                             │
│           ▼                                                         │
│  ┌────────────────────────────────────────┐                         │
│  │         MetricsCollecting              │                         │
│  └────────────────────────────────────────┘                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

`ARCMetricsMocks` also provides `RecordingSignpostTracer`, a ``SignpostTracing`` double that records every `emit`, `begin`, and `end` call.

## See Also

- ``MetricsCollecting``
- ``MetricsCollector``
- ``MetricSummary``
- ``DiagnosticSummary``
- <doc:GettingStarted>
- <doc:MigratingToV2>
