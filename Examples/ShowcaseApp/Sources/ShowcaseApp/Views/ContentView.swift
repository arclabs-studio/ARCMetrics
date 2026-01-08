import ARCMetricsKit
import SwiftUI

/// Main content view for the Showcase App
struct ContentView: View {
    @EnvironmentObject var viewModel: MetricsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            // Metrics Tab
            MetricsListView()
                .tabItem {
                    Label("Metrics", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            // Simulators Tab
            SimulatorsView()
                .tabItem {
                    Label("Simulators", systemImage: "hammer.fill")
                }
                .tag(2)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .alert("MetricKit Update", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var viewModel: MetricsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    StatusCard(viewModel: viewModel)

                    // Latest Metrics
                    if let latest = viewModel.latestMetrics {
                        LatestMetricsCard(summary: latest)
                    } else {
                        EmptyMetricsCard()
                    }

                    // Diagnostics Summary
                    DiagnosticsSummaryCard(viewModel: viewModel)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("ARCMetrics Showcase")
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    @ObservedObject var viewModel: MetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: viewModel.isCollecting ? "record.circle.fill" : "stop.circle.fill")
                    .foregroundColor(viewModel.isCollecting ? .green : .red)
                Text(viewModel.isCollecting ? "Collecting Metrics" : "Collection Paused")
                    .font(.headline)
            }

            if let lastUpdate = viewModel.lastUpdateTime {
                Text("Last Update: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(
                "Payloads: \(viewModel.metricSummaries.count) metrics, \(viewModel.diagnosticSummaries.count) diagnostics"
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Latest Metrics Card

struct LatestMetricsCard: View {
    let summary: MetricSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Metrics")
                .font(.headline)

            Divider()

            MetricRow(
                icon: "memorychip",
                label: "Peak Memory",
                value: "\(String(format: "%.1f", summary.peakMemoryUsageMB)) MB"
            )
            MetricRow(icon: "cpu", label: "Avg CPU", value: "\(String(format: "%.1f", summary.averageCPUPercentage))%")
            MetricRow(
                icon: "hourglass",
                label: "Hang Time",
                value: "\(String(format: "%.2f", summary.totalHangTimeSeconds))s"
            )
            MetricRow(
                icon: "timer",
                label: "Launch Time",
                value: "\(String(format: "%.2f", summary.averageLaunchTimeSeconds))s"
            )

            Text("Time Range: \(summary.timeRange)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Empty Metrics Card

struct EmptyMetricsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Metrics Yet")
                .font(.headline)

            Text("MetricKit delivers payloads approximately every 24 hours. Keep the app running and check back later!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Diagnostics Summary Card

struct DiagnosticsSummaryCard: View {
    @ObservedObject var viewModel: MetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics Summary")
                .font(.headline)

            Divider()

            if viewModel.diagnosticSummaries.isEmpty {
                Text("No diagnostic events recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                MetricRow(icon: "xmark.circle", label: "Total Crashes", value: "\(viewModel.totalCrashes)")
                MetricRow(icon: "exclamationmark.triangle", label: "Total Hangs", value: "\(viewModel.totalHangs)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(viewModel.totalCrashes > 0 ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
        .environmentObject(MetricsViewModel())
}
