import ARCMetricsKit
import SwiftUI

/// ARCMetrics Showcase App
///
/// This app demonstrates how to integrate and use ARCMetricsKit in a real application.
/// It provides:
/// - Live metrics visualization
/// - Scenario simulators to test different performance conditions
/// - Example implementations of metric handling
@main
struct ShowcaseApp: App {
    @StateObject private var metricsViewModel = MetricsViewModel()

    init() {
        // Initialize MetricKit collection
        MetricKitProvider.shared.startCollecting()

        print("🚀 ARCMetrics Showcase App Started")
        print("📊 MetricKit collection initialized")
        print("⏰ Metrics will be delivered every ~24 hours")
        print("💡 Use simulators to test different scenarios")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metricsViewModel)
        }
    }
}
