# Troubleshooting

Solutions to common issues when using ARCMetrics.

## Overview

This guide addresses frequently encountered issues when integrating and using ARCMetrics for performance monitoring.

## Common Issues

### No Metrics Received

**Symptom**: Your `for await` loops over `metricSummaries()` / `diagnosticSummaries()` never receive anything despite calling `startCollecting()`.

**Possible causes**:

1. **Testing in Simulator**: MetricKit has limited Simulator support
   - Solution: Test on a physical device

2. **Not enough time**: Metrics are delivered ~every 24 hours
   - Solution: Wait at least 24 hours for initial delivery

3. **Debug builds**: Some metrics require release builds
   - Solution: Test with TestFlight or Ad Hoc distribution

4. **Subscribed after delivery**: Streams don't replay — a subscriber sees only summaries delivered after it called `metricSummaries()` / `diagnosticSummaries()`
   - Solution: Subscribe early (for example in a `.task` on your root view), and read `pastMetricSummaries` / `pastDiagnosticSummaries` for anything delivered before

5. **macOS before 27**: The collector has no MetricKit backend there; `startCollecting()` logs "MetricKit is not available on this platform" and nothing is delivered

6. **A second collector**: Each ``MetricsCollector`` reads MetricKit independently. On iOS / macOS 27, two `MetricManager` readers each receive a non-deterministic subset of reports
   - Solution: Create one collector and inject it everywhere

```swift
// One collector, subscribed from the first view that appears
private let metrics = MetricsCollector()

var body: some Scene {
    WindowGroup {
        ContentView()
            .task {
                metrics.startCollecting()
                for await summary in metrics.metricSummaries() {
                    await analytics.send(summary)
                }
            }
    }
}
```

### Past Summaries Empty After Relaunch

**Symptom**: `pastMetricSummaries` / `pastDiagnosticSummaries` are empty at every launch on iOS or macOS 27, though they contained data on iOS 26.

**Cause**: `MetricManager` has no history API. On 27 these properties hold only summaries delivered in the current process.

**Solution**: Persist summaries yourself as they arrive. Both summary types are `Codable`.

### Incomplete Metric Data

**Symptom**: Some fields in `MetricSummary` are always 0.

**Possible causes**:

1. **Platform limitations**: Some metrics aren't available on all platforms
   - visionOS only supports diagnostics, not metrics
   - watchOS has limited metric availability

2. **iOS version**: Certain metrics require newer iOS versions
   - Check Apple's MetricKit documentation for availability

3. **No activity**: Zero values may be accurate if no activity occurred
   - `cellularDownloadMB` = 0 means no cellular data used

### Diagnostic Payloads Not Immediate

**Symptom**: Crash diagnostics take 24 hours to arrive.

**Cause**: Immediate delivery requires iOS 15+ or macOS 12+.

**Solution**:
- Update minimum deployment target to iOS 15+
- Or accept 24-hour delay on older versions

### Memory Warnings During Processing

**Symptom**: App receives memory warnings when processing large payloads.

**Solution**: Process payloads asynchronously and avoid storing raw data:

```swift
for await summary in metrics.metricSummaries() {
    // Process and send to backend immediately
    await analytics.send(summary)
    // Don't accumulate in memory
}
```

### Thread Safety Issues

**Symptom**: Crashes or unexpected behavior when accessing metrics from multiple threads.

**Cause**: MetricKit delivers reports on background threads of its choosing.

**Solution**: Iterate the stream on the main actor. A `.task` in a view, or an `async` method of a `@MainActor` view model, already runs there, so UI updates need no hop:

```swift
@MainActor
@Observable
final class MetricsViewModel {
    private(set) var latestMetrics: MetricSummary?
    private let collector: any MetricsCollecting

    init(collector: any MetricsCollecting) {
        self.collector = collector
    }

    func observeMetrics() async {
        for await summary in collector.metricSummaries() {
            latestMetrics = summary
        }
    }
}
```

### GPU Metrics Always Zero

**Symptom**: `cumulativeGPUTimeSeconds` is always 0.

**Possible causes**:

1. **No GPU work**: Your app may not perform significant GPU operations
   - UIKit/SwiftUI apps without custom Metal/SceneKit typically show minimal GPU usage

2. **Platform limitations**: GPU metrics availability varies
   - Full support on iOS and macOS
   - Limited on watchOS

3. **Measurement threshold**: Very brief GPU operations may not be captured
   - GPU time is aggregated; brief spikes may not register

**Solution**: GPU metrics are most relevant for graphics-intensive apps. If your app uses Metal, SceneKit, or heavy Core Animation, investigate further with Instruments.

### Disk Write Metrics Seem High

**Symptom**: `cumulativeDiskWritesMB` is unexpectedly high.

**Common causes**:

1. **Cache writes**: Aggressive caching strategies
   - Solution: Implement memory-based caching before disk

2. **Unbatched Core Data saves**:
   ```swift
   // Problem: Multiple individual saves
   for item in items {
       try context.save()  // Disk write for each!
   }

   // Solution: Batch saves
   for item in items {
       // modify items
   }
   try context.save()  // Single disk write
   ```

3. **Analytics/logging writes**: Writing logs synchronously
   - Solution: Buffer logs in memory and flush periodically

4. **Image caching**: Storing full-resolution images
   - Solution: Use thumbnail caching and lazy loading

### Hitch Ratio Unexpectedly High

**Symptom**: `hitchTimeRatio` or `scrollHitchTimeRatio` is above 5 ms/s despite smooth-looking scrolling.

> Note: Both values are in **milliseconds per second**. ARCMetrics 1.x multiplied `scrollHitchTimeRatio` by 100 and called it a percentage, so 1.x values — including any you persisted — are 100 times too large. See <doc:MigratingToV2>.

**Possible causes**:

1. **ProMotion devices**: 120Hz displays have stricter frame time budgets (8.33ms vs 16.67ms)
   - Test on non-ProMotion devices to compare

2. **Background work during scroll**:
   ```swift
   // Problem: Work on scroll
   func scrollViewDidScroll(_ scrollView: UIScrollView) {
       analytics.track("scroll")  // May cause micro-hitches
   }
   ```

3. **Complex cell configurations**: Expensive layout during cell appearance
   - Solution: Pre-calculate heights, use estimated row heights

4. **Image loading**: Decoding images on the main thread
   - Solution: Use `preparingForDisplay()` or background decoding

**Debugging hitches**: record with the **Animation Hitches** instrument — see <doc:InstrumentsIntegration>.

### Scroll Hitch Ratio Always Nil

**Symptom**: `scrollHitchTimeRatio` is `nil` on iOS 27.

**Cause**: `MetricManager` has no scroll-only hitch metric; only the `MXMetricManager` path (iOS before 27, visionOS) reports it, and only for `UIScrollView`.

**Solution**: Use `hitchTimeRatio`, which covers all tracked animations.

### Fewer Diagnostic Kinds on iOS 27

**Symptom**: On iOS or macOS 27 every `DiagnosticSummary` contains a single event, and app-launch or memory-exception diagnostics never appear.

**Cause**: Each `DiagnosticReport` is one event, and `DiagnosticSummary` has no fields for app-launch or memory-exception diagnostics, so those reports are skipped.

## Platform-Specific Notes

### iOS

- Full MetricKit support
- Diagnostic payloads immediate on iOS 15+
- iOS 27 uses `MetricManager` when built with Xcode 27; earlier iOS uses `MXMetricManager`
- Best tested via TestFlight

### macOS

- macOS 27: collected through `MetricManager` when built with Xcode 27
- macOS 14–26: no collection — ARCMetrics has no MetricKit backend there and logs a warning

### watchOS

- Limited metric availability
- Focus on battery and memory metrics
- Some display metrics not applicable

### visionOS

- **Diagnostics only**: Crash, hang, disk write, CPU exceptions
- **No performance metrics**: Memory, CPU, launch time not reported
- Compatible iPhone/iPad apps running in visionOS also affected

## Debugging Tips

### Enable Verbose Logging

ARCMetrics logs through the ARCLogger you pass to ``MetricsCollector/init(logger:)``. The default is `ARCLogger(category: "MetricKit")`. To also mirror debug lines to Xcode's console:

```swift
import ARCLogger
import ARCMetrics

let metrics = MetricsCollector(
    logger: ARCLogger(destinations: [ConsoleDestination(minimumLevel: .debug, mirrorsToStdout: true)],
                      category: "MetricKit")
)
```

### Verify Subscription

Check whether collection is running:

```swift
#if DEBUG
print("MetricKit collecting: \(metrics.isCollecting)")
#endif
```

### Simulate Payloads

Use Xcode's built-in simulation:
1. Connect a physical device — the menu item does not appear when running on the Simulator
2. Run app in debug mode
3. **Debug** → **MetricKit** → **Simulate MetricKit Payloads**

Simulated reports contain sample data, not measurements of your app.

## Getting Help

If you encounter issues not covered here:

1. Check [Apple's MetricKit documentation](https://developer.apple.com/documentation/metrickit)
2. Review [ARCMetrics GitHub issues](https://github.com/arclabs-studio/ARCMetrics/issues)
3. File a new issue with:
   - iOS/macOS version
   - Device model
   - Steps to reproduce
   - Relevant logs

## See Also

- <doc:GettingStarted>
- <doc:UnderstandingMetrics>
- <doc:MigratingToV2>
- ``MetricsCollector``
