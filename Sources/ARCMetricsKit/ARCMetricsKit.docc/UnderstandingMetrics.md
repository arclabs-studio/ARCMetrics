# Understanding Your Metrics

Learn how to interpret MetricKit data and identify performance issues.

## Overview

MetricKit provides a wealth of performance data, but knowing what the numbers mean is crucial for effective optimization. This guide explains each metric, typical values, and red flags to watch for.

## Memory Metrics

### Peak Memory Usage

**What it measures**: Maximum memory consumption during the reporting period.

**Typical values**:
- Small apps (simple utilities): 50-100 MB
- Medium apps (social, photo apps): 100-200 MB
- Large apps (games, media editors): 200-400 MB

**Warning signs**:
- ⚠️ >400 MB: High risk of termination on older devices
- 🔴 >500 MB: Almost certain termination on memory-constrained devices
- 📈 Trending upward: Possible memory leak

**How to investigate**:
1. Open Instruments → Memory Profiler
2. Reproduce high-memory scenarios
3. Look for:
   - Leaking objects (increasing allocations)
   - Large image caches
   - Unreleased resources

### Average Suspended Memory

**What it measures**: Memory usage while app is in background.

**Target**: <50 MB

**Why it matters**: Apps using excessive background memory are first to be terminated by the system.

**Optimization tips**:
- Release caches when entering background
- Unload images and large assets
- Cancel pending operations

## CPU Metrics

### Average CPU Percentage

**What it measures**: Percentage of available CPU used by your app.

**Typical values**:
- Idle state: <5%
- Light interactions: 5-20%
- Heavy processing: 20-50%
- Intensive tasks (video, games): 50-100%+

**Warning signs**:
- ⚠️ >30% while idle: Background processing issue
- 🔴 >80% sustained: Battery drain, device heating
- 📈 Increasing over time: Inefficient algorithms

**Values >100%**: Indicates multi-threaded CPU usage (normal for heavy workloads).

### Investigating High CPU

Use Instruments → Time Profiler:
1. Record your app during normal usage
2. Identify hot spots (functions consuming most CPU)
3. Focus on:
   - Tight loops
   - Expensive JSON parsing
   - Image processing on main thread
   - Unnecessary re-renders (SwiftUI)

## Responsiveness Metrics

### Hang Time

**What it measures**: Total time the main thread was blocked (>250ms).

**Target**: 0 seconds

**Why it matters**:
- Every second of hang time represents frozen UI
- Direct correlation with App Store ratings
- Primary cause of user frustration

**Severity levels**:
- 0-1s per day: Acceptable
- 1-5s per day: Moderate issue
- 5-10s per day: Serious problem
- >10s per day: Critical issue

### Common Hang Causes

1. **Synchronous network requests**
   ```swift
   // ❌ Bad: Blocks main thread
   let data = try Data(contentsOf: url)

   // ✅ Good: Async
   let (data, _) = try await URLSession.shared.data(from: url)
   ```

2. **Heavy computations on main thread**
   ```swift
   // ❌ Bad
   for image in images {
       processImage(image) // 50ms each × 100 images = 5s hang
   }

   // ✅ Good
   await withTaskGroup(of: ProcessedImage.self) { group in
       for image in images {
           group.addTask { await processImage(image) }
       }
   }
   ```

3. **Core Data on main thread**
4. **Large JSON decoding**
5. **File I/O without dispatch queue**

### Finding Hangs in Instruments

1. Open Instruments → Main Thread Checker
2. Look for:
   - Red flags indicating main thread violations
   - Long-running tasks on main thread
   - Synchronous operations

## Launch Time Metrics

### Average Launch Time

**What it measures**: Time from app launch to first frame rendered.

**Typical values**:
- Fast: <0.5s (excellent UX)
- Acceptable: 0.5-1.0s
- Slow: 1.0-2.0s (users notice)
- Very slow: >2.0s (unacceptable)

**Apple's guideline**: <400ms to first frame.

### Optimizing Launch Time

**Defer non-critical work**:
```swift
@main
struct MyApp: App {
    init() {
        // ✅ Critical only
        FirebaseManager.configure()
        MetricKitProvider.shared.startCollecting()

        // ❌ Defer these
        // AnalyticsManager.identifyUser()
        // CacheManager.warmCache()
        // NotificationCenter.requestPermissions()
    }
}
```

**Use Instruments → App Launch**:
1. Profile your app launch
2. Identify expensive initializers
3. Move work to background or defer until after first frame

## Network Metrics

### Cellular vs WiFi Usage

**What it measures**: Data transferred over each network type.

**Why it matters**: Users pay for cellular data; excessive usage leads to uninstalls.

**Best practices**:
- Download large assets only on WiFi
- Compress images before upload
- Implement smart prefetching
- Cache aggressively

**Example implementation**:
```swift
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.usesInterfaceType(.cellular) {
        // Disable large downloads
        ContentPrefetcher.shared.pause()
    }
}
```

## Diagnostic Metrics

### Crashes

**Target**: 0 crashes

**Reality**: <0.1% crash rate is acceptable (but aim for 0).

**Crash rate calculation**:
```
Crash Rate = (Crashes / Sessions) × 100
```

**Industry benchmarks**:
- Excellent: <0.01%
- Good: 0.01-0.1%
- Needs improvement: 0.1-1.0%
- Poor: >1.0%

### Investigating Crashes

1. Check `DiagnosticSummary.crashes` for:
   - Exception type (e.g., `EXC_BAD_ACCESS`)
   - Signal (e.g., `SIGSEGV`)
   - Termination reason

2. Common crash types:
   - `EXC_BAD_ACCESS`: Memory corruption, use-after-free
   - `SIGABRT`: Forced termination (asserts, exceptions)
   - `SIGILL`: Invalid instruction (rare)
   - `SIGKILL`: OS terminated app (out of memory)

3. Use crash stack traces:
   - MetricKit provides JSON stacktraces
   - Symbolicate using `.dSYM` files
   - Integrate with crash reporting (Crashlytics, Sentry)

## Setting Thresholds

Create alerts when metrics exceed thresholds:

```swift
func evaluateMetrics(_ summary: MetricSummary) {
    // Memory alert
    if summary.peakMemoryUsageMB > 400 {
        sendAlert("High memory usage: \(summary.peakMemoryUsageMB) MB")
    }

    // Hang alert
    if summary.totalHangTimeSeconds > 5.0 {
        sendAlert("Excessive hangs: \(summary.totalHangTimeSeconds)s")
    }

    // Launch time alert
    if summary.averageLaunchTimeSeconds > 2.0 {
        sendAlert("Slow launches: \(summary.averageLaunchTimeSeconds)s")
    }

    // CPU alert
    if summary.averageCPUPercentage > 50 {
        sendAlert("High CPU usage: \(summary.averageCPUPercentage)%")
    }
}
```

## Summary: Red Flags

Watch for these warning signs:

| Metric | Warning Threshold | Critical Threshold |
|--------|------------------|-------------------|
| Peak Memory | >300 MB | >500 MB |
| Hang Time | >5s/day | >10s/day |
| Launch Time | >1.0s | >2.0s |
| Avg CPU | >30% idle | >80% sustained |
| Crash Rate | >0.1% | >1.0% |

## Next Steps

- Correlate MetricKit data with Instruments: <doc:InstrumentsIntegration>
- Troubleshooting: <doc:TroubleshootingAndFAQ>
