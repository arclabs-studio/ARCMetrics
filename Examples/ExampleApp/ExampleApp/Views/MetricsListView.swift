//
//  MetricsListView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import ARCMetrics
import SwiftUI

struct MetricsListView: View {
    // MARK: - Private Properties

    @Environment(MetricsViewModel.self) var viewModel
    @State private var showingExportSheet = false
    @State private var exportedText = ""

    // MARK: - View

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if viewModel.metricSummaries.isEmpty {
                        Text("No metric summaries received yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(viewModel.metricSummaries.enumerated()), id: \.offset) { index, summary in
                            NavigationLink {
                                MetricDetailView(summary: summary, index: index)
                            } label: {
                                MetricSummaryRow(summary: summary, index: index)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Metric Summaries")
                        Spacer()
                        Text("\(viewModel.metricSummaries.count)")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    if viewModel.diagnosticSummaries.isEmpty {
                        Text("No diagnostic events received")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(viewModel.diagnosticSummaries.enumerated()), id: \.offset) { index, summary in
                            NavigationLink {
                                DiagnosticDetailView(summary: summary, index: index)
                            } label: {
                                DiagnosticSummaryRow(summary: summary, index: index)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Diagnostic Events")
                        Spacer()
                        Text("\(viewModel.diagnosticSummaries.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("All Metrics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            exportedText = viewModel.exportMetrics()
                            showingExportSheet = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive,
                               action: { viewModel.clearAllMetrics() },
                               label: { Label("Clear All", systemImage: "trash") })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                NavigationStack {
                    ScrollView {
                        Text(exportedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                    }
                    .navigationTitle("Export")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingExportSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Metric Summary Row

struct MetricSummaryRow: View {
    let summary: MetricSummary
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Metric #\(index + 1)")
                    .font(.headline)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
            }

            Text(summary.timeRange)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                MetricBadge(label: "Memory", value: "\(summary.peakMemoryUsageMB.fixed(0))MB")
                MetricBadge(label: "CPU", value: "\(summary.averageCPUPercentage.fixed(0))%")
                MetricBadge(label: "Hangs", value: "\(summary.totalHangTimeSeconds.fixed(1))s")
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Diagnostic Summary Row

struct DiagnosticSummaryRow: View {
    let summary: DiagnosticSummary
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Diagnostic #\(index + 1)")
                    .font(.headline)
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(summary.crashCount > 0 ? .red : .orange)
            }

            Text(summary.timeRange)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                MetricBadge(label: "Crashes", value: "\(summary.crashCount)", color: .red)
                MetricBadge(label: "Hangs", value: "\(summary.hangCount)", color: .orange)
                MetricBadge(label: "Disk", value: "\(summary.diskWriteExceptionCount)", color: .yellow)
            }
            .font(.caption2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let label: String
    let value: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Metric Detail View

struct MetricDetailView: View {
    let summary: MetricSummary
    let index: Int

    var body: some View {
        List {
            Section("Time Range") {
                Text(summary.timeRange)
            }

            Section("Memory") {
                DetailRow(label: "Peak Memory", value: "\(summary.peakMemoryUsageMB.fixed(2)) MB")
                DetailRow(label: "Average Suspended",
                          value: "\(summary.averageMemoryUsageMB.fixed(2)) MB")
            }

            Section("CPU") {
                DetailRow(label: "Cumulative Time",
                          value: "\(summary.cumulativeCPUTimeSeconds.fixed(2))s")
                DetailRow(label: "Average Percentage",
                          value: "\(summary.averageCPUPercentage.fixed(2))%")
            }

            Section("GPU") {
                DetailRow(label: "Cumulative GPU Time",
                          value: "\(summary.cumulativeGPUTimeSeconds.fixed(2))s")
            }

            Section("Disk I/O") {
                DetailRow(label: "Disk Writes", value: "\(summary.cumulativeDiskWritesMB.fixed(2)) MB")
            }

            Section("Animation") {
                DetailRow(label: "Hitch Rate",
                          value: summary.hitchTimeRatio
                              .map { "\($0.formatted(.number.precision(.fractionLength(2)))) ms/s" } ?? "n/a")
            }

            Section("Responsiveness") {
                DetailRow(label: "Total Hang Time", value: "\(summary.totalHangTimeSeconds.fixed(3))s")
                DetailRow(label: "Launch Time", value: "\(summary.averageLaunchTimeSeconds.fixed(3))s")
            }

            Section("Usage Time") {
                DetailRow(label: "Foreground Time", value: "\(summary.foregroundTimeSeconds.fixed(1))s")
                DetailRow(label: "Background Time", value: "\(summary.backgroundTimeSeconds.fixed(1))s")
            }

            Section("Network") {
                DetailRow(label: "Cellular Download", value: "\(summary.cellularDownloadMB.fixed(2)) MB")
                DetailRow(label: "Cellular Upload", value: "\(summary.cellularUploadMB.fixed(2)) MB")
                DetailRow(label: "WiFi Download", value: "\(summary.wifiDownloadMB.fixed(2)) MB")
                DetailRow(label: "WiFi Upload", value: "\(summary.wifiUploadMB.fixed(2)) MB")
            }
        }
        .navigationTitle("Metric #\(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Diagnostic Detail View

struct DiagnosticDetailView: View {
    let summary: DiagnosticSummary
    let index: Int

    var body: some View {
        List {
            Section("Time Range") {
                Text(summary.timeRange)
            }

            Section("Overview") {
                DetailRow(label: "Crashes", value: "\(summary.crashCount)")
                DetailRow(label: "Hangs", value: "\(summary.hangCount)")
                DetailRow(label: "Disk Write Exceptions", value: "\(summary.diskWriteExceptionCount)")
                DetailRow(label: "CPU Exceptions", value: "\(summary.cpuExceptionCount)")
            }

            if !summary.crashes.isEmpty {
                Section("Crash Details") {
                    ForEach(Array(summary.crashes.enumerated()), id: \.offset) { crashIndex, crash in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Crash #\(crashIndex + 1)")
                                .font(.headline)

                            if let exceptionType = crash.exceptionType {
                                DetailRow(label: "Exception", value: exceptionType)
                            }
                            if let signal = crash.signal {
                                DetailRow(label: "Signal", value: signal)
                            }
                            if let terminationReason = crash.terminationReason {
                                DetailRow(label: "Reason", value: terminationReason)
                            }
                        }
                    }
                }
            }

            if !summary.hangs.isEmpty {
                Section("Hang Details") {
                    ForEach(Array(summary.hangs.enumerated()), id: \.offset) { hangIndex, hang in
                        DetailRow(label: "Hang #\(hangIndex + 1)", value: "\(hang.duration.fixed(3))s")
                    }
                }
            }
        }
        .navigationTitle("Diagnostic #\(index + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("With Data") {
    MetricsListView()
        .environment(MetricsViewModel.preview)
}

#Preview("Empty State") {
    MetricsListView()
        .environment(MetricsViewModel.emptyPreview)
}
