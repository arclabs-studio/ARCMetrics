# Troubleshooting and FAQ

Common issues and solutions when working with ARCMetricsKit and MetricKit.

## Common Issues

### Not Receiving Any Payloads

**Symptom**: Callbacks never fire, no metrics received.

**Possible causes**:

1. **Didn't call `startCollecting()`**
   ```swift
   // ✅ Make sure you call this
   MetricKitProvider.shared.startCollecting()
   ```

2. **Running in debug/simulator**
   - MetricKit works best on **physical devices**
   - **Debug builds** may delay payloads by 2-3 days
   - **Release builds** receive payloads more reliably

3. **App not running long enough**
   - MetricKit needs at least **24 hours** of usage
   - Try: Use app for a few minutes, then wait 24-48 hours

4. **Not enough user sessions**
   - MetricKit requires **multiple app sessions**
   - Single launch may not be enough

**Solution**: Install a TestFlight build, use for 2-3 days, check logs.

### Payloads Arrive Late

**Symptom**: Metrics from 2-3 days ago, not yesterday.

**Expected behavior**: This is normal for MetricKit.

- Apple aggregates data before delivery
- Payloads may arrive 24-72 hours after the events
- Not a bug—it's how MetricKit works

### Incomplete Metrics

**Symptom**: Some fields are 0 or nil.

**Causes**:

1. **Not all metrics collected every time**
   - MetricKit only includes relevant data
   - If no hangs occurred, `totalHangTimeSeconds` = 0

2. **iOS version differences**
   - Older iOS versions support fewer metrics
   - Check `@available` annotations

3. **Simulator limitations**
   - Many metrics unavailable in Simulator
   - Always test on device

### High Memory in MetricKit but Not Instruments

**Symptom**: MetricKit shows 500 MB, Instruments shows 200 MB.

**Explanation**: Different measurement methods.

- **MetricKit**: Peak across all users over 24 hours
- **Instruments**: Your specific test session

**What to do**:
1. Check if memory is trending upward
2. Profile with Instruments during heavy usage
3. Test on older devices (lower memory limits)

### No Crash Reports in MetricKit

**Symptom**: App crashes but `crashCount` = 0.

**Possible reasons**:

1. **Crashes not yet delivered**
   - Wait 24-48 hours after crash

2. **Using separate crash reporter**
   - Crashlytics/Sentry may intercept crashes
   - MetricKit might not receive them

3. **Crash during termination**
   - Some crashes (force quit) aren't captured

**Solution**: Use MetricKit + dedicated crash reporter (Crashlytics).

## FAQ

### When will I receive my first payload?

**Typically 24-48 hours** after:
1. Calling `startCollecting()`
2. Using the app for a few sessions
3. Having the app in the background/closed

On **TestFlight** or **production**, this is more reliable.

### Can I test MetricKit in the Simulator?

**Limited**. Many metrics are unavailable:
- ✅ Available: Basic structure
- ❌ Unavailable: Most actual metric values

Always test on a **real device**.

### How much battery does MetricKit use?

**Negligible**. MetricKit is designed for production use with minimal overhead.

Apple's telemetry shows <0.1% battery impact.

### Can I get real-time metrics?

**No**. MetricKit is **not real-time**. It delivers aggregated data every 24 hours.

For real-time monitoring, use:
- Instruments (during development)
- Custom performance tracking

### Do I need to ask for user permission?

**No**. MetricKit doesn't require user consent because:
- No PII collected
- Data is aggregated and anonymized
- Apple-managed, privacy-preserving

### How long is data retained?

**7 days**. If you don't retrieve payloads within 7 days, Apple deletes them.

**Best practice**: Retrieve and send to your backend within 24 hours.

### Can I disable MetricKit in production?

**Yes**, but not recommended.

```swift
// To disable
MetricKitProvider.shared.stopCollecting()
```

However, losing production metrics makes debugging issues much harder.

### What's the difference between MetricKit and Crashlytics?

| Feature | MetricKit | Crashlytics |
|---------|-----------|-------------|
| Crash reports | ✅ Basic | ✅ Detailed |
| Hangs | ✅ Yes | ❌ No |
| Memory metrics | ✅ Yes | ❌ No |
| CPU metrics | ✅ Yes | ❌ No |
| Real-time | ❌ No | ✅ Yes |
| Symbolication | Manual | Automatic |
| Dashboard | DIY | Built-in |

**Recommendation**: Use **both**:
- MetricKit for performance metrics
- Crashlytics for crash reporting

### Why are my CPU percentages >100%?

**Normal for multi-threaded apps**.

- 100% = One full CPU core
- 200% = Two full CPU cores
- 400% = Four full CPU cores

Modern devices have 4-8 cores, so 400% CPU is possible (and sometimes good—means you're using parallelism).

### Can I track custom metrics?

**No**. MetricKit only collects system-level metrics.

For custom metrics (e.g., "time to load restaurant list"), use:
- Firebase Analytics
- Custom analytics endpoint
- Instruments (development only)

### How do I send metrics to my backend?

```swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    Task {
        for summary in summaries {
            try? await sendToBackend(summary)
        }
    }
}

func sendToBackend(_ summary: MetricSummary) async throws {
    let endpoint = URL(string: "https://api.yourapp.com/metrics")!

    let payload: [String: Any] = [
        "timeRange": summary.timeRange,
        "peakMemoryMB": summary.peakMemoryUsageMB,
        "avgCPU": summary.averageCPUPercentage,
        "hangTimeSeconds": summary.totalHangTimeSeconds
        // ... other metrics
    ]

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (_, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw MetricsError.uploadFailed
    }
}
```

### Should I check metrics on every app version?

**Yes**. Track metrics per version to catch regressions:

```swift
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

let payload: [String: Any] = [
    "appVersion": appVersion,
    "metrics": summary.dictionary
]
```

### What happens if the app is force-quit?

MetricKit data is **preserved**. Apple stores it and delivers it in the next payload.

## Getting Help

### Logging

Enable verbose logging to debug issues:

```swift
// ARCLogger automatically logs MetricKit events
// Check Console.app or Xcode console for:
// [MetricKit] Received N metric payload(s)
// [MetricKit] Received N diagnostic payload(s)
```

### Support

- **GitHub Issues**: [github.com/arclabs-studio/ARCMetrics/issues](https://github.com/arclabs-studio/ARCMetrics/issues)
- **Documentation**: This DocC documentation
- **Apple Documentation**: [developer.apple.com/metrickit](https://developer.apple.com/documentation/metrickit)

## Next Steps

- Return to getting started: <doc:GettingStarted>
- Learn to interpret metrics: <doc:UnderstandingMetrics>
- Correlate with Instruments: <doc:InstrumentsIntegration>
