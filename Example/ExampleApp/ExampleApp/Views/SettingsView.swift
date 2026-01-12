//
//  SettingsView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Private Properties

    @EnvironmentObject var viewModel: MetricsViewModel
    @State private var showingClearAlert = false

    // MARK: - View

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.isCollecting },
                        set: { _ in viewModel.toggleCollection() }
                    )) {
                        Label("Collect Metrics", systemImage: "chart.bar.fill")
                    }
                    .tint(.blue)
                } header: {
                    Text("MetricKit Collection")
                } footer: {
                    Text("When enabled, ARCMetricsKit will collect performance metrics from MetricKit. Metrics are delivered approximately every 24 hours.")
                }

                Section {
                    Button(role: .destructive) {
                        showingClearAlert = true
                    } label: {
                        Label("Clear All Metrics", systemImage: "trash")
                    }
                    .disabled(!viewModel.hasReceivedMetrics)
                } header: {
                    Text("Data Management")
                }

                Section {
                    StatRow(label: "Metric Summaries", value: "\(viewModel.metricSummaries.count)")
                    StatRow(label: "Diagnostic Events", value: "\(viewModel.diagnosticSummaries.count)")
                    StatRow(label: "Total Crashes", value: "\(viewModel.totalCrashes)")
                    StatRow(label: "Total Hangs", value: "\(viewModel.totalHangs)")

                    if let lastUpdate = viewModel.lastUpdateTime {
                        HStack {
                            Text("Last Update")
                            Spacer()
                            Text(lastUpdate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Statistics")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About ARCMetrics", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: "https://developer.apple.com/documentation/metrickit")!) {
                        Label("MetricKit Documentation", systemImage: "book")
                    }

                    Link(destination: URL(string: "https://github.com/arclabs-studio/ARCMetrics")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                } header: {
                    Text("Resources")
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("ARCMetricsKit")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Metrics?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearAllMetrics()
                }
            } message: {
                Text("This will remove all stored metrics from the app. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - About View

struct AboutView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("ARCMetrics")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Native MetricKit Integration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)

                    Text("ARCMetricsKit provides a simplified interface to Apple's MetricKit framework, making it easy to collect and analyze performance metrics from your production apps.")
                        .font(.body)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Metrics Collected")
                        .font(.headline)

                    MetricTypeRow(icon: "memorychip", title: "Memory", description: "Peak & average usage")
                    MetricTypeRow(icon: "cpu", title: "CPU", description: "Utilization percentage")
                    MetricTypeRow(icon: "gpu", title: "GPU", description: "Graphics processing time")
                    MetricTypeRow(icon: "externaldrive", title: "Disk I/O", description: "Write activity")
                    MetricTypeRow(icon: "scroll", title: "Animation", description: "Scroll hitch ratio")
                    MetricTypeRow(icon: "hourglass", title: "Hangs", description: "UI freeze time")
                    MetricTypeRow(icon: "timer", title: "Launches", description: "Time to first frame")
                    MetricTypeRow(icon: "network", title: "Network", description: "Cellular & WiFi usage")
                    MetricTypeRow(icon: "xmark.circle", title: "Crashes", description: "Detailed crash reports")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("License")
                        .font(.headline)

                    Text("MIT License - ARC Labs Studio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Metric Type Row

struct MetricTypeRow: View {

    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView()
        .environmentObject(MetricsViewModel.preview)
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}
