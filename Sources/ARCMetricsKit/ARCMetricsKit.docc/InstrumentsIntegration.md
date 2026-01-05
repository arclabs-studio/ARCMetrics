# Correlating MetricKit with Instruments

Learn how to use Instruments alongside MetricKit to diagnose and fix performance issues.

## Overview

MetricKit tells you **what** is slow; Instruments tells you **why**. This guide shows you how to use both tools together for maximum insight.

## The MetricKit + Instruments Workflow

### 1. Identify Issues with MetricKit

MetricKit provides production metrics from real users:

```swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        if summary.totalHangTimeSeconds > 5.0 {
            print("🚨 Users experiencing hangs!")
            // Now investigate with Instruments
        }
    }
}
```

### 2. Reproduce in Instruments

Once you identify an issue in MetricKit, use Instruments to find the root cause.

## Memory Issues

### MetricKit Shows High Memory

```
Peak Memory: 487 MB ⚠️
```

### Investigate in Instruments

1. **Xcode → Product → Profile** (⌘I)
2. Select **Allocations** template
3. Record while using your app
4. Look for:
   - Persistent allocations (never freed)
   - Growing heap over time
   - Large object allocations

### Key Instruments Features

**Allocations Instrument**:
- Shows all memory allocations
- Identifies leaking objects
- Tracks object lifecycle

**Leaks Instrument**:
- Automatically detects memory leaks
- Shows reference cycles
- Highlights leaked objects in red

**VM Tracker**:
- Shows virtual memory regions
- Identifies large mapped files
- Detects memory pressure

### Example: Finding an Image Cache Leak

```swift
// MetricKit shows: Peak memory climbing from 200MB → 500MB
// Instruments reveals: UIImage allocations never released

// ❌ Problem code
class ImageCache {
    private var cache: [String: UIImage] = [:]

    func cache(_ image: UIImage, for key: String) {
        cache[key] = image // Never cleared!
    }
}

// ✅ Fix: Add eviction policy
class ImageCache {
    private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        return cache
    }()
}
```

## CPU Issues

### MetricKit Shows High CPU

```
Average CPU: 67% ⚠️
```

### Investigate in Instruments

1. **Xcode → Product → Profile** (⌘I)
2. Select **Time Profiler** template
3. Record while reproducing high CPU usage
4. Look at **Call Tree**:
   - Sort by "Self" time
   - Identify hot functions
   - Focus on main thread

### Reading the Time Profiler

**Main Thread (Critical)**:
- Any function taking >16ms per frame causes jank
- Look for expensive operations:
  - JSON decoding
  - Image processing
  - Complex views (SwiftUI body)

**Background Threads (Less Critical)**:
- High CPU is okay if not impacting main thread
- Check for unnecessary parallelization

### Example: SwiftUI Performance Issue

```swift
// MetricKit shows: High CPU during scrolling
// Instruments reveals: Heavy `body` computation

// ❌ Problem code
struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        HStack {
            // Expensive: Computed every frame!
            Image(processedImageName)
            Text(restaurant.name)
        }
    }

    var processedImageName: String {
        // Heavy string processing
        restaurant.photos.first?
            .components(separatedBy: "/").last?
            .replacingOccurrences(of: ".jpg", with: "") ?? ""
    }
}

// ✅ Fix: Compute once
struct RestaurantRow: View {
    let restaurant: Restaurant
    let imageName: String

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        self.imageName = // Compute once
            restaurant.photos.first?
                .components(separatedBy: "/").last?
                .replacingOccurrences(of: ".jpg", with: "") ?? ""
    }
}
```

## Hang Issues

### MetricKit Shows Hangs

```
Total Hang Time: 8.3s ⚠️
```

### Investigate in Instruments

1. **Xcode → Product → Profile** (⌘I)
2. Select **System Trace** or **Main Thread Checker** template
3. Record while reproducing hangs
4. Look for:
   - Red blocks on main thread (>250ms)
   - Synchronous network calls
   - File I/O on main thread

### Example: Finding a Network Hang

```swift
// MetricKit shows: 8 seconds of hangs per day
// Instruments reveals: URLSession synchronous call

// ❌ Problem code (causes hang)
func loadUser() {
    let url = URL(string: "https://api.example.com/user")!
    let data = try? Data(contentsOf: url) // ⚠️ Blocks main thread!
    // Process data...
}

// ✅ Fix: Use async/await
func loadUser() async throws {
    let url = URL(string: "https://api.example.com/user")!
    let (data, _) = try await URLSession.shared.data(from: url)
    // Process data...
}
```

## Launch Time Issues

### MetricKit Shows Slow Launches

```
Average Launch Time: 2.3s ⚠️
```

### Investigate in Instruments

1. **Xcode → Product → Profile** (⌘I)
2. Select **App Launch** template
3. Profile app launch
4. Look at phases:
   - **Pre-main**: dyld loading
   - **Initialization**: Static initializers, +load methods
   - **UIApplication init**: App delegate
   - **First frame**: View hierarchy

### Example: Slow Launch Fix

```swift
// MetricKit shows: 2.3s launch time
// Instruments reveals: Network request in AppDelegate

// ❌ Problem code
@main
struct MyApp: App {
    init() {
        FirebaseApp.configure()

        // ⚠️ Blocks launch!
        fetchRemoteConfig()
        warmImageCache()
        requestNotificationPermissions()
    }
}

// ✅ Fix: Defer non-critical work
@main
struct MyApp: App {
    init() {
        FirebaseApp.configure()

        // Defer after first frame
        Task {
            try await Task.sleep(for: .seconds(0.5))
            fetchRemoteConfig()
            warmImageCache()
            requestNotificationPermissions()
        }
    }
}
```

## Network Issues

### MetricKit Shows High Data Usage

```
Cellular Download: 250 MB ⚠️
```

### Investigate in Instruments

1. **Xcode → Product → Profile** (⌘I)
2. Select **Network** template
3. Record while using app
4. Look for:
   - Large requests
   - Uncompressed data
   - Redundant requests

### HTTP Traffic Analysis

Instruments shows:
- Request/response sizes
- Request frequency
- Response times

## Creating a Performance Dashboard

Combine MetricKit and Instruments data:

```swift
struct PerformanceDashboard {
    let metricKitData: MetricSummary
    let instrumentsSession: URL? // Link to Instruments trace

    var alerts: [Alert] {
        var alerts: [Alert] = []

        if metricKitData.peakMemoryUsageMB > 400 {
            alerts.append(Alert(
                severity: .high,
                message: "High memory",
                action: "Profile with Allocations instrument",
                instrumentsTemplate: .allocations
            ))
        }

        if metricKitData.totalHangTimeSeconds > 5 {
            alerts.append(Alert(
                severity: .critical,
                message: "Excessive hangs",
                action: "Profile with Main Thread Checker",
                instrumentsTemplate: .mainThreadChecker
            ))
        }

        return alerts
    }
}
```

## Best Practices

### 1. Monitor Trends, Not Absolutes

Don't just look at single values—track changes over time:

```swift
struct MetricTrend {
    let current: MetricSummary
    let previous: MetricSummary

    var memoryTrend: TrendDirection {
        if current.peakMemoryUsageMB > previous.peakMemoryUsageMB * 1.2 {
            return .worsening // +20% = problem
        }
        return .stable
    }
}
```

### 2. Segment by Device

Performance varies by device:

```swift
if deviceIsOld {
    // Lower thresholds for older devices
    memoryThreshold = 200 // MB
} else {
    memoryThreshold = 400 // MB
}
```

### 3. Correlate with App Version

Track metrics per app version to catch regressions:

```
Version 1.0: Avg launch 0.8s ✅
Version 1.1: Avg launch 1.9s ⚠️ (regression!)
```

## Instruments Templates Quick Reference

| Issue | Instruments Template | What It Shows |
|-------|---------------------|---------------|
| High memory | Allocations | All memory allocations |
| Memory leaks | Leaks | Reference cycles, leaked objects |
| High CPU | Time Profiler | Function execution time |
| Hangs | System Trace | Main thread blocks |
| Slow launch | App Launch | Launch phases timing |
| Network usage | Network | HTTP traffic analysis |
| Disk I/O | File Activity | Reads/writes to disk |
| Battery drain | Energy Log | Power consumption |

## Summary

**MetricKit → Identifies problems in production**
**Instruments → Diagnoses root causes in development**

Always use both tools together for effective performance optimization.

## Next Steps

- Return to metric interpretation: <doc:UnderstandingMetrics>
- Troubleshooting: <doc:TroubleshootingAndFAQ>
