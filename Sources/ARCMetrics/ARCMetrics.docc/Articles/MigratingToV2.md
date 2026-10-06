# Migrating to ARCMetrics 2.0

Replace the callback singleton with an owned collector and async streams, and update code that reads hitch ratios.

## Overview

ARCMetrics 2.0 adopts Apple's iOS / macOS 27 `MetricManager` API. Its reports arrive as async sequences, and Apple recommends a single `MetricManager` per app, because two tasks iterating the same sequence each receive a non-deterministic subset of reports. The package's public API follows that model:

| 1.x | 2.0 |
|-----|-----|
| `MetricKitProvider.shared` | One ``MetricsCollector`` the app creates and keeps |
| `MetricKitProvider.shared.configure(logger:)` | ``MetricsCollector/init(logger:)`` |
| `onMetricPayloadsReceived` callback | `for await` over ``MetricsCollecting/metricSummaries()`` |
| `onDiagnosticPayloadsReceived` callback | `for await` over ``MetricsCollecting/diagnosticSummaries()`` |
| `MetricsProviding` | ``MetricsCollecting`` |
| `MockMetricsProvider` (internal to the package's tests; apps wrote their own) | `MockMetricsCollector` in the `ARCMetricsMocks` product |
| `scrollHitchTimeRatio: Double` (documented as %) | ``MetricSummary/scrollHitchTimeRatio`` `: Double?`, ms per second |
| — | ``MetricSummary/hitchTimeRatio`` `: Double?`, ms per second |

The signpost API (``SignpostTracing``, ``MetricKitSignpostTracer``, ``SignpostCategory``, ``SignpostInterval``, ``NoOpSignpostTracer``) is unchanged.

## Update the Dependency

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics.git", from: "2.0.0")
]
```

Add `ARCMetricsMocks` to your test target if you used `MockMetricsProvider`:

```swift
.testTarget(
    name: "YourAppTests",
    dependencies: [
        .product(name: "ARCMetrics", package: "ARCMetrics"),
        .product(name: "ARCMetricsMocks", package: "ARCMetrics")
    ]
)
```

## Replace the Singleton with an Owned Collector

There is no `shared` instance any more. Create **one** collector at your composition root and keep it for the app's lifetime.

**Before (1.x):**

```swift
@main
struct MyApp: App {
    init() {
        MetricKitProvider.shared.configure(logger: ARCLogger(category: "Metrics"))
        MetricKitProvider.shared.startCollecting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**After (2.0):**

```swift
import ARCLogger
import ARCMetrics

@main
struct MyApp: App {
    private let metrics = MetricsCollector(logger: ARCLogger(category: "Metrics"))

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

``MetricsCollector/startCollecting()`` and ``MetricsCollector/stopCollecting()`` are idempotent, as in 1.x. Pass the same instance to everything that needs it — do not create a second collector.

## Replace Callbacks with Async Streams

Each call to ``MetricsCollecting/metricSummaries()`` or ``MetricsCollecting/diagnosticSummaries()`` returns a new, independent `AsyncStream` that receives every summary delivered from then on. Several consumers can listen at once without stealing summaries from each other — in 1.x, assigning the callback a second time silently replaced the first consumer.

Streams deliver one summary per element, where the callbacks delivered an array.

**Before (1.x):**

```swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        sendToAnalytics(summary)
    }
}

MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    for summary in summaries where summary.crashCount > 0 {
        alertCrashReporting(summary)
    }
}
```

**After (2.0):** consume the streams in a `.task`, which cancels the iteration when the view goes away:

```swift
WindowGroup {
    ContentView()
        .task {
            for await summary in metrics.metricSummaries() {
                await analytics.send(summary)
            }
        }
        .task {
            for await summary in metrics.diagnosticSummaries() where summary.crashCount > 0 {
                await crashReporter.report(summary)
            }
        }
}
```

Each `.task` runs once per window, so on iPad a scene with two windows has two subscribers. Put a sink that must run exactly once — such as an analytics upload — somewhere that exists once, like your composition root.

> Important: Streams do not replay. A subscriber sees only summaries delivered after it subscribed. Read ``MetricsCollecting/pastMetricSummaries`` and ``MetricsCollecting/pastDiagnosticSummaries`` for earlier ones — but don't forward both the history and the stream to the same sink, or you count summaries twice.

## Inject MetricsCollecting Instead of MetricsProviding

**Before (1.x):**

```swift
@MainActor
@Observable
final class MetricsViewModel {
    private(set) var latestMetrics: MetricSummary?

    init(metricsProvider: MetricsProviding = MetricKitProvider.shared) {
        metricsProvider.onMetricPayloadsReceived = { [weak self] summaries in
            Task { @MainActor in self?.latestMetrics = summaries.last }
        }
    }
}
```

**After (2.0):**

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

The view drives the subscription with `.task { await viewModel.observeMetrics() }`, so it ends when the view disappears. There is no `[weak self]` callback and no hop to the main actor: the loop runs on the view model's actor.

## Replace MockMetricsProvider with MockMetricsCollector

`MockMetricsCollector` (in `ARCMetricsMocks`) conforms to ``MetricsCollecting`` and multicasts like the real collector.

| `MockMetricsProvider` (1.x) | `MockMetricsCollector` (2.0) |
|-----------------------------|------------------------------|
| `simulateMetricPayload(_:)` | `simulate(metric:)` |
| `simulateDiagnosticPayload(_:)` | `simulate(diagnostic:)` |
| `pastMetricSummaries` / `pastDiagnosticSummaries` filled by the `simulate…` calls | Fixed history passed to `init(pastMetricSummaries:pastDiagnosticSummaries:)`; `simulate` does not add to it |
| Call counters | `startCollectingCallCount`, `stopCollectingCallCount` |

**Before (1.x):**

```swift
func testCrashIsForwarded() {
    let mock = MockMetricsProvider()
    var crash = DiagnosticSummary(timeRange: "Test")
    crash.crashCount = 1

    mock.simulateDiagnosticPayload(crash)

    XCTAssertEqual(mock.pastDiagnosticSummaries, [crash])
}
```

**After (2.0):**

```swift
import ARCMetrics
import ARCMetricsMocks
import Testing

@Test func crashIsDelivered() async {
    // Given
    let collector = MockMetricsCollector()
    let diagnostics = collector.diagnosticSummaries() // subscribe first: no replay
    var crash = DiagnosticSummary(timeRange: "Test")
    crash.crashCount = 1

    // When
    collector.simulate(diagnostic: crash)

    // Then
    var iterator = diagnostics.makeAsyncIterator()
    #expect(await iterator.next() == crash)
}
```

Simulating before anything has subscribed delivers to no one, exactly as with the real collector. Subscribe — call ``MetricsCollecting/diagnosticSummaries()`` — before you call `simulate(diagnostic:)`.

If you tested signposts with a hand-written recorder, `ARCMetricsMocks` now ships `RecordingSignpostTracer`, which records `events` and exposes `beginCount`, `endCount`, and `openedIDs`.

## Update Hitch Ratio Handling

### scrollHitchTimeRatio Changed Unit and Type

``MetricSummary/scrollHitchTimeRatio`` is now `Double?` in **milliseconds per second**. In 1.x it was a non-optional `Double` documented as a percentage.

1.x multiplied MetricKit's value by 100, assuming MetricKit reported a `0...1` ratio. MetricKit actually reports milliseconds per second, so every 1.x value was **100 times too large**: a 1.x reading of `250` is really 2.5 ms/s.

- Divide any threshold you wrote for 1.x by 100, or switch to Apple's ms-per-second targets below.
- Summaries you persisted with 1.x decode unchanged, so their `scrollHitchTimeRatio` is still 100 times too large. Divide stored 1.x values by 100 before comparing them with 2.0 values.
- The value is `nil` on iOS and macOS 27: `MetricManager` has no scroll-only metric. Only the `MXMetricManager` path (iOS before 27, visionOS) fills it, and only for `UIScrollView`.

```swift
// Before (1.x): a "percentage" that was really ms/s × 100
if summary.scrollHitchTimeRatio > 5 {
    reportJank(summary)
}

// After (2.0): ms per second; prefer the all-animations figure
if let ratio = summary.hitchTimeRatio ?? summary.scrollHitchTimeRatio, ratio > 5 {
    reportJank(summary)
}
```

### Prefer hitchTimeRatio

``MetricSummary/hitchTimeRatio`` is new: hitch time across all tracked animations, in milliseconds per second, perception-adjusted by Apple. It is filled on iOS / macOS 27 and on the iOS / visionOS 26 legacy path, and `nil` on earlier OS versions.

| Hitch time ratio | Assessment |
|------------------|------------|
| < 5 ms/s | Good |
| 5–10 ms/s | Noticeable |
| > 10 ms/s | Investigate |

Targets from Apple's WWDC20 session *Eliminate animation hitches with XCTest*.

## Account for Platform Differences on 27

### History Is Process-Local on iOS and macOS 27

`MetricManager` has no equivalent of `MXMetricManager.pastPayloads`. On iOS and macOS 27, ``MetricsCollector/pastMetricSummaries`` and ``MetricsCollector/pastDiagnosticSummaries`` contain only summaries delivered **in the current process** — they start empty at every launch. Below 27 they still read MetricKit's on-device history.

If you need history across launches on 27, persist summaries yourself as they arrive. Both summary types are `Codable`.

### One Diagnostic Summary per Event

On iOS and macOS 27 each `DiagnosticReport` is a single event, so each ``DiagnosticSummary`` holds exactly one crash, one hang, or one CPU / disk-write exception. Code that summed counts across a summary still works; code that expected several events per summary will see more, smaller summaries.

App-launch and memory-exception diagnostics produce no summary, because ``DiagnosticSummary`` has no field for them.

### Backend Selection

``MetricsCollector`` picks the backend at runtime; you don't choose it:

| Platform | Backend |
|----------|---------|
| iOS 27, macOS 27 | `MetricManager` |
| iOS 17–26, visionOS (all) | `MXMetricManager` subscriber |
| macOS 14–26 | None — logs a warning and delivers nothing, as in 1.x |

The `MetricManager` backend is compiled only with the Swift 6.4 toolchain (Xcode 27). Built with an older Xcode, iOS 27 devices use the `MXMetricManager` subscriber.

## See Also

- <doc:GettingStarted>
- <doc:UnderstandingMetrics>
- ``MetricsCollector``
- ``MetricsCollecting``
