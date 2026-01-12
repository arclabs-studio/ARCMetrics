# ExampleApp

Demo application for ARCMetricsKit.

## Requirements

- Xcode 16.0+
- iOS 17.0+

## Running the Example

1. Open `ExampleApp/ExampleApp.xcodeproj` in Xcode
2. The package is referenced locally from the parent directory
3. Select a simulator and press Run (⌘R)

## Regenerating the Project (if needed)

If you need to regenerate the Xcode project after modifying `project.yml`:

```bash
brew install xcodegen  # if not installed
cd Example/ExampleApp
xcodegen generate
```

## Features Demonstrated

- **MetricKit Integration**: Collecting performance metrics with `MetricKitProvider`
- **Callbacks**: Handling metric and diagnostic payload callbacks
- **Live Dashboard**: Real-time visualization of received metrics
- **Performance Simulators**: Testing different performance scenarios

## Project Structure

```
ExampleApp/
├── ExampleApp.swift          # App entry point
├── Views/
│   ├── ContentView.swift     # Main TabView with Dashboard
│   ├── MetricsListView.swift # Metrics list and details
│   ├── SimulatorsView.swift  # Performance simulators
│   └── SettingsView.swift    # Settings and About
├── ViewModels/
│   └── MetricsViewModel.swift # Metrics state management
├── Helpers/
│   └── PreviewHelpers.swift  # Preview sample data
└── Assets.xcassets/          # App assets
```

## Demo Screens

| Screen | Purpose |
|--------|---------|
| **Dashboard** | Main hub with latest metrics and status |
| **Metrics** | List of all received metric and diagnostic summaries |
| **Simulators** | Performance scenario triggers (CPU, Memory, Hangs, etc.) |
| **Settings** | Toggle collection, clear data, app info |

## Notes

- MetricKit delivers payloads approximately every 24 hours
- Physical device recommended for accurate metrics
- Use simulators to generate test scenarios
