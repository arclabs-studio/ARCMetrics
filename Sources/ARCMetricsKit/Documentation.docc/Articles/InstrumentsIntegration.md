# Instruments Integration

Correlate MetricKit data with Xcode Instruments for deeper performance analysis.

## Overview

While MetricKit provides production metrics, Xcode Instruments helps you diagnose issues during development. This guide shows how to use both tools together for comprehensive performance analysis.

## Correlating Metrics with Instruments

### Memory Issues

When ``MetricSummary/peakMemoryUsageMB`` is high:

1. Open **Instruments** → **Leaks**
2. Profile your app during typical usage
3. Look for leaked objects and retain cycles
4. Use **Allocations** instrument to track memory growth

```
MetricKit: Peak Memory = 450 MB
Instruments: Shows UIImage objects growing unbounded
Solution: Implement image caching with size limits
```

### CPU Issues

When ``MetricSummary/averageCPUPercentage`` is elevated:

1. Open **Instruments** → **Time Profiler**
2. Record during normal app usage
3. Look for methods consuming excessive CPU time
4. Focus on main thread activity

```
MetricKit: Avg CPU = 65%
Instruments: JSON parsing on main thread taking 40%
Solution: Move parsing to background queue
```

### Hang Investigation

When ``MetricSummary/totalHangTimeSeconds`` > 0:

1. Open **Instruments** → **Time Profiler**
2. Enable **Record Waiting Threads**
3. Look for main thread blocks > 250ms
4. Check for synchronous network calls, heavy computation, or lock contention

```
MetricKit: Hang Time = 3.5s
Instruments: Main thread blocked waiting for network response
Solution: Use async/await for network calls
```

### Launch Time Analysis

When ``MetricSummary/averageLaunchTimeSeconds`` > 1.0s:

1. Open **Instruments** → **App Launch**
2. Profile a cold launch
3. Identify work happening before first frame
4. Look for unnecessary initializations

```
MetricKit: Launch Time = 2.1s
Instruments: Firebase initialization taking 800ms
Solution: Defer non-critical initialization
```

## Debug MetricKit Payloads

### Simulating Payloads in Xcode

Xcode provides built-in MetricKit simulation:

1. Run your app on a connected device
2. Go to **Debug** → **Simulate MetricKit Payload**
3. Choose the payload type to simulate
4. Your app's callbacks will receive test data

### Using the Organizer

View historical MetricKit data:

1. Open **Window** → **Organizer**
2. Select your app
3. Navigate to **Metrics** tab
4. Review aggregated data from App Store users

## Workflow Example

Here's a typical workflow for investigating a performance regression:

```
1. MetricKit alert: Launch time increased from 0.8s to 1.5s

2. Check timeline:
   - When did it start? (correlate with releases)
   - Which versions affected?

3. Local reproduction:
   - Instruments → App Launch
   - Profile cold launch
   - Compare with previous version

4. Identify root cause:
   - New SDK initialization
   - Database migration on launch
   - Asset loading changes

5. Fix and verify:
   - Implement fix
   - Profile again in Instruments
   - Deploy and monitor MetricKit
```

## Best Practices

1. **Profile regularly**: Don't wait for MetricKit alerts
2. **Compare baselines**: Keep Instruments traces from known-good versions
3. **Test on older devices**: Performance issues are more visible on constrained hardware
4. **Use release builds**: Debug builds have different performance characteristics

## See Also

- <doc:UnderstandingMetrics>
- <doc:Troubleshooting>
- [Instruments User Guide](https://help.apple.com/instruments)
