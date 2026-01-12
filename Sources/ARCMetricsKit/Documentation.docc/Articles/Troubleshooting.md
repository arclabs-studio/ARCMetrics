# Troubleshooting

Solutions to common issues when using ARCMetricsKit.

## Overview

This guide addresses frequently encountered issues when integrating and using ARCMetricsKit for performance monitoring.

## Common Issues

### No Metrics Received

**Symptom**: Callbacks are never invoked despite calling `startCollecting()`.

**Possible causes**:

1. **Testing in Simulator**: MetricKit has limited Simulator support
   - Solution: Test on a physical device

2. **Not enough time**: Metrics are delivered ~every 24 hours
   - Solution: Wait at least 24 hours for initial delivery

3. **Debug builds**: Some metrics require release builds
   - Solution: Test with TestFlight or Ad Hoc distribution

4. **Callbacks set after start**: Callbacks were set too late
   - Solution: Set callbacks before calling `startCollecting()`

```swift
// Correct order
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    // Handle metrics
}
MetricKitProvider.shared.startCollecting() // Call AFTER setting callbacks
```

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
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    Task {
        for summary in summaries {
            // Process and send to backend immediately
            await analytics.send(summary)
            // Don't accumulate in memory
        }
    }
}
```

### Thread Safety Issues

**Symptom**: Crashes or unexpected behavior when accessing metrics from multiple threads.

**Cause**: MetricKit callbacks may be invoked on background threads.

**Solution**: Dispatch to main thread for UI updates:

```swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    Task { @MainActor in
        self.updateUI(with: summaries)
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
       context.save()  // Disk write for each!
   }

   // Solution: Batch saves
   for item in items {
       // modify items
   }
   context.save()  // Single disk write
   ```

3. **Analytics/logging writes**: Writing logs synchronously
   - Solution: Buffer logs in memory and flush periodically

4. **Image caching**: Storing full-resolution images
   - Solution: Use thumbnail caching and lazy loading

### Scroll Hitch Ratio Unexpectedly High

**Symptom**: `scrollHitchTimeRatio` is > 5% despite smooth-looking scrolling.

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

**Debugging scroll hitches**:

```swift
// Enable hitches logging in debug builds
#if DEBUG
CAMetalLayer.enableHitchIndicator = true
#endif
```

## Platform-Specific Notes

### iOS

- Full MetricKit support
- Diagnostic payloads immediate on iOS 15+
- Best tested via TestFlight

### macOS

- MetricKit available on macOS 12+
- Mac Catalyst apps fully supported
- Native macOS apps fully supported

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

ARCMetricsKit uses ARCLogger internally. Enable debug logging:

```swift
// In your app's initialization
ARCLogger.setMinimumLevel(.debug)
```

### Verify Subscription

Check if MetricKit subscription is active:

```swift
// In debug builds
#if DEBUG
print("MetricKit subscribers: \(MXMetricManager.shared)")
#endif
```

### Simulate Payloads

Use Xcode's built-in simulation:
1. Connect physical device
2. Run app in debug mode
3. **Debug** → **Simulate MetricKit Payload**

## Getting Help

If you encounter issues not covered here:

1. Check [Apple's MetricKit documentation](https://developer.apple.com/documentation/metrickit)
2. Review [ARCMetricsKit GitHub issues](https://github.com/arclabs-studio/ARCMetrics/issues)
3. File a new issue with:
   - iOS/macOS version
   - Device model
   - Steps to reproduce
   - Relevant logs

## See Also

- <doc:GettingStarted>
- <doc:UnderstandingMetrics>
- ``MetricKitProvider``
