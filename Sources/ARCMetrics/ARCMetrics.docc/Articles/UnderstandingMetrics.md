# Understanding Your Metrics

Learn how to interpret the performance data collected by ARCMetrics.

## Overview

ARCMetrics provides two types of summaries: ``MetricSummary`` for performance metrics and ``DiagnosticSummary`` for crash and hang diagnostics. This guide explains what each metric means and what values you should target.

## Performance Metrics

### Memory Usage

```swift
summary.peakMemoryUsageMB    // Maximum memory at any point
summary.averageMemoryUsageMB // Average while suspended
```

| Value | Assessment | Action |
|-------|------------|--------|
| < 100 MB | Excellent | Maintain current approach |
| 100-200 MB | Good | Monitor for growth |
| 200-400 MB | Warning | Investigate memory usage |
| > 500 MB | Critical | Risk of termination on older devices |

> Tip: High `averageMemoryUsageMB` while suspended indicates your app isn't releasing resources when backgrounded.

### CPU Usage

```swift
summary.cumulativeCPUTimeSeconds // Total CPU time consumed
summary.averageCPUPercentage     // Calculated percentage
```

The `averageCPUPercentage` is calculated as:

```
(cumulativeCPUTime / foregroundTime) × 100
```

| Value | Assessment | Impact |
|-------|------------|--------|
| < 5% | Excellent | Minimal battery impact |
| 5-20% | Normal | Expected for active apps |
| 20-50% | High | Noticeable battery drain |
| > 50% | Critical | Major battery impact |

> Note: Values over 100% indicate multi-core CPU usage.

### Hang Time

```swift
summary.totalHangTimeSeconds // Total unresponsive time
```

Hangs occur when the main thread is blocked for more than 250ms.

| Value | Assessment | User Impact |
|-------|------------|-------------|
| 0s | Perfect | Fully responsive |
| 0-1s | Acceptable | Occasional stutters |
| 1-5s | Poor | Frustrated users |
| > 5s | Critical | Users will abandon app |

> Warning: Any hang time above 0 should be investigated. Use Instruments' Time Profiler to identify blocking operations.

### Launch Time

```swift
summary.averageLaunchTimeSeconds // Time to first frame
```

| Value | Assessment | User Perception |
|-------|------------|-----------------|
| < 0.5s | Excellent | Instant |
| 0.5-1.0s | Good | Quick |
| 1.0-2.0s | Acceptable | Noticeable delay |
| > 2.0s | Poor | Users may abandon |

### Network Usage

```swift
summary.cellularDownloadMB  // Cellular download
summary.cellularUploadMB    // Cellular upload
summary.wifiDownloadMB      // WiFi download
summary.wifiUploadMB        // WiFi upload
```

Monitor cellular usage carefully as users on limited data plans will notice excessive usage.

### GPU Usage

```swift
summary.cumulativeGPUTimeSeconds // Total GPU time consumed
```

GPU time measures the total time your app spent executing GPU work. High values indicate graphics-intensive operations that impact battery life.

| Value | Assessment | Impact |
|-------|------------|--------|
| < 1s | Minimal | Low battery impact |
| 1-10s | Moderate | Noticeable for heavy usage |
| 10-60s | High | Significant battery drain |
| > 60s | Critical | Major power consumption |

> Note: GPU metrics are particularly important for apps using Metal, SceneKit, RealityKit, or heavy Core Animation effects.

### Disk I/O

```swift
summary.cumulativeDiskWritesMB // Total logical disk writes
```

Disk write activity affects device performance and battery life. Excessive writes can also contribute to flash storage wear.

| Value | Assessment | Action |
|-------|------------|--------|
| < 10 MB | Excellent | Normal operation |
| 10-50 MB | Moderate | Review write patterns |
| 50-200 MB | High | Implement batching/caching |
| > 200 MB | Excessive | Urgent optimization needed |

> Tip: Consider batching writes, using write-ahead logging, and caching frequently-written data in memory before persisting.

### Animation Performance

```swift
summary.hitchTimeRatio       // All tracked animations, ms per second (Double?)
summary.scrollHitchTimeRatio // UIScrollView scrolling only, ms per second (Double?)
```

A "hitch" is a frame that reaches the screen late, causing visible stuttering. Both ratios are the total hitch time in **milliseconds per second** of animation.

``MetricSummary/hitchTimeRatio`` covers all tracked animations and is adjusted by Apple for human perception, which makes it the best single smoothness figure. It is reported on iOS / macOS 27 and on iOS / visionOS 26; it is `nil` on earlier OS versions.

``MetricSummary/scrollHitchTimeRatio`` covers `UIScrollView` scrolling only, and only the `MXMetricManager` path (iOS before 27, visionOS) reports it. It is `nil` on iOS and macOS 27.

| Hitch time ratio | Assessment | User Experience |
|------------------|------------|-----------------|
| < 5 ms/s | Good | Smooth |
| 5-10 ms/s | Noticeable | Users notice occasional stutters |
| > 10 ms/s | Poor | Investigate — frustrating experience |

Targets from Apple's WWDC20 session *Eliminate animation hitches with XCTest*.

> Warning: Users are highly sensitive to scroll performance. Target < 5 ms/s for a good experience.

> Important: ARCMetrics 1.x reported `scrollHitchTimeRatio` as a "percentage" that was really ms per second × 100. Values from 1.x, including any you persisted, are 100 times too large. See <doc:MigratingToV2>.

Common causes of hitches:
- Complex cell layouts being calculated on scroll
- Image decoding on the main thread
- Expensive shadow or corner radius rendering
- Excessive view hierarchy depth

## Diagnostic Events

### Crashes

```swift
summary.crashCount          // Number of crashes
summary.crashes             // Array of CrashInfo
```

Each `CrashInfo` contains:
- `exceptionType`: The exception (e.g., "EXC_BAD_ACCESS")
- `signal`: The signal (e.g., "SIGSEGV")
- `terminationReason`: System-provided reason
- `virtualMemoryRegionInfo`: Memory region details

> Important: Any crash count > 0 requires immediate investigation.

### Hangs

```swift
summary.hangCount           // Number of hang events
summary.hangs               // Array of HangInfo
```

Each `HangInfo` contains the `duration` in seconds:

| Duration | Severity | Priority |
|----------|----------|----------|
| 0.25-0.5s | Minor | Low |
| 0.5-1.0s | Moderate | Medium |
| > 1.0s | Severe | High |

### Resource Exceptions

```swift
summary.diskWriteExceptionCount // Excessive disk writes
summary.cpuExceptionCount       // Excessive CPU usage
```

These indicate your app exceeded system thresholds for resource usage.

## Best Practices

1. **Establish baselines**: Collect metrics for several weeks to understand normal patterns
2. **Set alerts**: Configure your analytics backend to alert on significant changes
3. **Correlate with releases**: Track metrics against app versions to identify regressions
4. **Prioritize by impact**: Focus on metrics that affect user experience most

## See Also

- ``MetricSummary``
- ``DiagnosticSummary``
- <doc:InstrumentsIntegration>
