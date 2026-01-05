# ARCMetrics Showcase App

An interactive demonstration app for **ARCMetricsKit** that shows how to integrate and use MetricKit in a real iOS/macOS application.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platform](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)

---

## 🎯 Purpose

This showcase app demonstrates:

- ✅ How to integrate ARCMetricsKit into a SwiftUI app
- ✅ Real-time visualization of received metrics
- ✅ Proper implementation of MetricKit callbacks
- ✅ Performance scenario simulators
- ✅ Best practices for handling metric data
- ✅ Example UI for displaying metrics to developers

## 🚀 Running the App

### Prerequisites

- Xcode 15+
- iOS 17+ device or simulator (metrics collection limited in simulator)
- macOS 14+ for Mac target

### Steps

1. **Open the workspace or package**
   ```bash
   cd Examples/ShowcaseApp
   open Package.swift
   ```

2. **Build and run**
   - Select the ShowcaseApp scheme
   - Choose your target device (physical device recommended)
   - Press ⌘R to build and run

3. **Wait for metrics**
   - MetricKit delivers payloads approximately every **24 hours**
   - Use simulators to generate performance events
   - Check back in 24-48 hours to see real metrics

## 📱 App Features

### 1. Dashboard Tab

The main overview showing:
- Collection status (active/paused)
- Latest metrics summary
- Diagnostics overview
- Quick stats

**Key Metrics Displayed:**
- Peak Memory Usage
- Average CPU Percentage
- Total Hang Time
- Launch Time
- Network Usage

### 2. Metrics Tab

Detailed list of all received metrics:
- **Metric Summaries**: Performance data (memory, CPU, hangs, etc.)
- **Diagnostic Events**: Crashes, hangs, exceptions
- Tap any item to see full details
- Export functionality for sharing data

**Features:**
- View complete metric history
- Navigate to detailed views
- Export all metrics as text
- Clear stored data

### 3. Simulators Tab

Interactive simulators to test MetricKit:

#### Memory Pressure Simulator
- Allocates large arrays to increase memory usage
- Helps test memory metrics collection
- **Expected Result**: Higher peak memory in next payload

#### CPU Intensive Task
- Performs heavy calculations using multiple threads
- Tests CPU metrics
- **Expected Result**: Increased CPU usage percentage

#### Main Thread Hang
- Intentionally blocks the main thread for 1 second
- ⚠️ **Warning**: This will freeze the UI
- **Expected Result**: Hang time reported in diagnostics

#### Background Work
- Simulates background processing tasks
- Tests background CPU and time metrics
- **Expected Result**: Background time increases

#### Network Activity
- Makes multiple HTTP requests
- Tests network usage metrics
- **Expected Result**: Network data transfer recorded

### 4. Settings Tab

Configuration and information:
- Toggle MetricKit collection on/off
- Clear all stored metrics
- View statistics
- Links to documentation
- About information

## 🔍 How to Use

### Basic Workflow

1. **Launch the app**
   - MetricKit collection starts automatically
   - Status shown in Dashboard

2. **Generate performance events**
   - Use the Simulators tab to trigger different scenarios
   - Or just use the app normally

3. **Wait for delivery**
   - MetricKit aggregates data over 24 hours
   - Payloads are delivered in batches
   - Not immediate—this is expected behavior

4. **View metrics**
   - Check Dashboard for latest summary
   - Browse Metrics tab for full history
   - Export data for analysis

### Understanding the Data

#### Metric Summary Fields

| Field | What It Means | Good Value |
|-------|---------------|------------|
| Peak Memory | Max memory used | <300 MB |
| Avg CPU | CPU usage % | <30% |
| Hang Time | UI freeze time | 0s |
| Launch Time | Time to first frame | <1s |

#### Diagnostic Events

- **Crashes**: Critical failures requiring investigation
- **Hangs**: UI freezes >250ms
- **Disk Write Exceptions**: Excessive disk activity
- **CPU Exceptions**: Sustained high CPU usage

## 💡 Testing Tips

### For Best Results

1. **Use a physical device**
   - Simulator has limited MetricKit support
   - Real device provides accurate metrics

2. **Install via TestFlight**
   - Production builds receive metrics more reliably
   - Debug builds may have delays

3. **Generate diverse events**
   - Run all simulators
   - Use the app normally
   - Launch and close multiple times

4. **Be patient**
   - First payload typically arrives in 24-48 hours
   - Subsequent payloads are more regular
   - This is normal MetricKit behavior

5. **Check logs**
   - Console.app shows MetricKit events
   - Look for "Received N metric payload(s)"
   - Helpful for debugging

### Common Issues

#### Not Receiving Metrics?

**Possible causes:**
- Not enough time has passed (wait 24-48 hours)
- Running in simulator (use device)
- App not used enough (launch multiple times)
- Debug build (try TestFlight)

**Solutions:**
- Install via TestFlight
- Use app for several sessions
- Wait 2-3 days
- Check Console.app logs

#### Metrics Seem Wrong?

**Remember:**
- MetricKit shows **aggregated** data
- Values are from **all users/sessions**
- Not just your current session
- Peak values may be from edge cases

## 🏗️ Architecture

### Project Structure

```
ShowcaseApp/
├── ShowcaseApp.swift          # App entry point
├── ViewModels/
│   └── MetricsViewModel.swift # State management
├── Views/
│   ├── ContentView.swift      # Main container
│   ├── MetricsListView.swift  # Metrics list
│   ├── SimulatorsView.swift   # Performance simulators
│   └── SettingsView.swift     # Settings & about
└── README.md                   # This file
```

### Key Components

#### MetricsViewModel
- Manages metric state (`@Published` properties)
- Handles MetricKit callbacks
- Provides export functionality
- Thread-safe with `@MainActor`

#### ContentView
- Tab-based navigation
- Dashboard with latest metrics
- Alert presentation

#### MetricsListView
- Lists all received metrics
- Detail views for each payload
- Export capability

#### SimulatorsView
- Performance scenario triggers
- Status feedback
- Async task management

## 🎓 Learning from the Code

### Example: Setting Up MetricKit

```swift
// In ShowcaseApp.swift
init() {
    // Start collection early in app lifecycle
    MetricKitProvider.shared.startCollecting()
}
```

### Example: Handling Callbacks

```swift
// In MetricsViewModel.swift
MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    Task { @MainActor in
        // Update UI on main thread
        self.metricSummaries.append(contentsOf: summaries)
        self.lastUpdateTime = Date()
    }
}
```

### Example: Displaying Metrics

```swift
// In ContentView.swift
if let latest = viewModel.latestMetrics {
    Text("Peak Memory: \(latest.peakMemoryUsageMB) MB")
    Text("Avg CPU: \(latest.averageCPUPercentage)%")
}
```

## 📚 Additional Resources

- **ARCMetricsKit Documentation**: See parent package README
- **MetricKit Guide**: Understanding metrics and thresholds
- **Instruments Integration**: Correlating MetricKit with Instruments
- **Apple Documentation**: [MetricKit Framework](https://developer.apple.com/documentation/metrickit)

## 🐛 Troubleshooting

### Build Issues

**"No such module 'ARCMetricsKit'"**
- Ensure the parent package is resolved
- Clean build folder (⇧⌘K)
- Rebuild package dependencies

**"Cannot find 'ARCLogger' in scope"**
- ARCLogger dependency not resolved
- Check parent Package.swift configuration

### Runtime Issues

**App crashes on launch**
- Check console for error messages
- Ensure ARCMetricsKit is properly linked
- Verify iOS/macOS version requirements

**Simulators don't work**
- Check permissions
- Review console logs
- Ensure app is running (not paused)

## 📝 Notes

### Important Reminders

- ⏰ **Metrics are not real-time** - delivered every ~24 hours
- 📱 **Physical device recommended** - simulator has limitations
- 🔒 **No PII collected** - all data is aggregated and anonymous
- 📊 **Production data** - reflects real user experience

### Differences from Production

This showcase app includes:
- **UI for developers**: Not needed in production apps
- **Simulators**: For testing only
- **Detailed logging**: More verbose than production
- **Export features**: For analysis and debugging

In your production app, you would typically:
- Call `startCollecting()` in app initialization
- Register callbacks to send metrics to your backend
- Not show metrics UI to end users
- Log errors only, not all events

## 🔗 Links

- **Main Package**: [../../README.md](../../README.md)
- **ARCMetricsKit Docs**: [../../Sources/ARCMetricsKit/ARCMetricsKit.docc/](../../Sources/ARCMetricsKit/ARCMetricsKit.docc/)
- **GitHub**: [https://github.com/arclabs/ARCMetrics](https://github.com/arclabs/ARCMetrics)

---

**Questions or Issues?**

Open an issue on GitHub or check the main ARCMetrics documentation.
