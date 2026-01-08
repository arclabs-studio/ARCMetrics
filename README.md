# ARCMetrics

Native MetricKit integration for collecting production performance metrics from Apple platform apps.

> Part of the ARC Labs Studio package ecosystem

## 🎯 Features

- ✅ Complete MetricKit integration
- ✅ Simplified API with callbacks
- ✅ Comprehensive DocC documentation
- ✅ Production-ready monitoring
- ✅ Privacy-preserving (no PII)
- ✅ Zero external dependencies (except ARCLogger)
- ✅ Instruments correlation guide

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arclabs-studio/ARCMetrics.git", from: "1.0.0")
]
```

## 🚀 Quick Start

```swift
import ARCMetricsKit

@main
struct MyApp: App {
    init() {
        MetricKitProvider.shared.startCollecting()
    }
}
```

## 📊 What Metrics Are Collected?

- **Memory**: Peak & average usage
- **CPU**: Utilization percentage
- **Hangs**: UI freeze time
- **Launches**: Time to first frame
- **Network**: Cellular & WiFi usage
- **Crashes**: Detailed crash reports
- **Battery**: Energy consumption

## 📚 Documentation

Full DocC documentation included:

- **Getting Started**: Quick integration guide
- **Understanding Metrics**: Interpret your data
- **Instruments Integration**: Debug with Xcode tools
- **Troubleshooting**: Common issues & FAQ

Build docs:
```bash
swift package generate-documentation
```

## 🔍 Example Usage

```swift
// Register callbacks
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    for summary in summaries {
        print("📊 Peak Memory: \(summary.peakMemoryUsageMB) MB")
        print("⚡️ Avg CPU: \(summary.averageCPUPercentage)%")

        // Send to your backend
        sendToAnalytics(summary)
    }
}

MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    for summary in summaries {
        if summary.crashCount > 0 {
            alertCrashSystem(summary)
        }
    }
}
```

## 🎮 Showcase App

Want to see ARCMetricsKit in action? Check out the **interactive showcase app**!

The showcase app demonstrates:
- Complete integration example
- Real-time metrics visualization
- Performance scenario simulators
- Best practices implementation

```bash
cd Examples/ShowcaseApp
open Package.swift
```

[**View Showcase README →**](Examples/ShowcaseApp/README.md)

**Features:**
- 📊 Dashboard with live metrics
- 📝 Detailed metrics history
- 🔨 Performance simulators (memory, CPU, hangs)
- ⚙️ Settings and configuration
- 📖 Interactive learning experience

Perfect for understanding how MetricKit works before integrating into your production app!

## ⚠️ Important Notes

- Metrics are delivered **every ~24 hours** (not real-time)
- Works best on **physical devices** (limited in Simulator)
- **TestFlight/Production** recommended for testing
- Data is **aggregated and anonymous**

## 🧪 Testing

```bash
swift test
```

## 📱 Platform Support

- iOS 17+
- macOS 14+
- watchOS 10+
- visionOS 1+

## 📄 License

MIT License - ARC Labs Studio

## 🔗 Related Packages

- [ARCLogger](https://github.com/arclabs-studio/ARCLogger) - Logging system
- [ARCFirebase](https://github.com/arclabs-studio/ARCFirebase) - Firebase integration
