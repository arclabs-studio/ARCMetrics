//
//  MetricsViewModel.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import ARCMetrics
import SwiftUI

@Observable @MainActor
// swiftlint:disable:next observable_viewmodel
final class MetricsViewModel {
    // MARK: - Properties

    private let collector: any MetricsCollecting

    var metricSummaries: [MetricSummary] = []
    var diagnosticSummaries: [DiagnosticSummary] = []
    var isCollecting = true
    var lastUpdateTime: Date?
    var showingAlert = false
    var alertMessage: String = ""

    // MARK: - Computed Properties

    var latestMetrics: MetricSummary? {
        metricSummaries.last
    }

    var totalCrashes: Int {
        diagnosticSummaries.reduce(0) { $0 + $1.crashCount }
    }

    var totalHangs: Int {
        diagnosticSummaries.reduce(0) { $0 + $1.hangCount }
    }

    var hasReceivedMetrics: Bool {
        !metricSummaries.isEmpty || !diagnosticSummaries.isEmpty
    }

    // MARK: - Initialization

    /// - Parameter collector: The app's single collector. Create one and keep
    ///   it: ARCMetrics reads MetricKit once and multicasts from there.
    init(collector: any MetricsCollecting = MetricsCollector()) {
        self.collector = collector
    }

    // MARK: - Actions

    /// Starts collection and consumes both summary streams until the calling
    /// task is cancelled. Call it from the root view's `.task`.
    func observeMetrics() async {
        collector.startCollecting()
        async let metrics: Void = receiveMetricSummaries()
        async let diagnostics: Void = receiveDiagnosticSummaries()
        _ = await (metrics, diagnostics)
    }

    func toggleCollection() {
        if isCollecting {
            collector.stopCollecting()
            print("MetricKit collection stopped")
        } else {
            collector.startCollecting()
            print("MetricKit collection started")
        }
        isCollecting.toggle()
    }

    func clearAllMetrics() {
        metricSummaries.removeAll()
        diagnosticSummaries.removeAll()
        lastUpdateTime = nil
        print("All metrics cleared")
    }

    func exportMetrics() -> String {
        var export = "# ARCMetrics Export\n\n"
        export += "Generated: \(Date().formatted())\n\n"

        export += "## Metric Summaries (\(metricSummaries.count))\n\n"
        for (index, summary) in metricSummaries.enumerated() {
            export += "### Summary \(index + 1)\n"
            export += "```\n\(summary.description)\n```\n\n"
        }

        export += "## Diagnostic Summaries (\(diagnosticSummaries.count))\n\n"
        for (index, summary) in diagnosticSummaries.enumerated() {
            export += "### Diagnostic \(index + 1)\n"
            export += "```\n\(summary.description)\n```\n\n"
        }

        return export
    }
}

// MARK: - Private Functions

extension MetricsViewModel {
    private func receiveMetricSummaries() async {
        for await summary in collector.metricSummaries() {
            print("Received a metric summary")

            metricSummaries.append(summary)
            lastUpdateTime = Date()

            if metricSummaries.count == 1 {
                showAlert(title: "Metrics Received!", message: "Received your first metric summary")
            }

            logMetricSummary(summary)
        }
    }

    private func receiveDiagnosticSummaries() async {
        for await summary in collector.diagnosticSummaries() {
            print("Received a diagnostic summary")

            diagnosticSummaries.append(summary)
            lastUpdateTime = Date()

            if summary.crashCount > 0 {
                showAlert(title: "Crash Detected",
                          message: "Detected \(summary.crashCount) crash(es) in the diagnostic summary")
            }

            logDiagnosticSummary(summary)
        }
    }

    private func showAlert(title: String, message: String) {
        alertMessage = "\(title)\n\n\(message)"
        showingAlert = true
    }

    private func logMetricSummary(_ summary: MetricSummary) {
        print("""
        Metric Summary:
        - Time Range: \(summary.timeRange)
        - Peak Memory: \(String(format: "%.1f", summary.peakMemoryUsageMB)) MB
        - Avg CPU: \(String(format: "%.1f", summary.averageCPUPercentage))%
        - GPU Time: \(String(format: "%.2f", summary.cumulativeGPUTimeSeconds))s
        - Disk Writes: \(String(format: "%.1f", summary.cumulativeDiskWritesMB)) MB
        - Hitch Rate: \(summary.hitchTimeRatio
            .map { "\($0.formatted(.number.precision(.fractionLength(1)))) ms/s" } ?? "n/a")
        - Hang Time: \(String(format: "%.2f", summary.totalHangTimeSeconds))s
        - Launch Time: \(String(format: "%.2f", summary.averageLaunchTimeSeconds))s
        """)
    }

    private func logDiagnosticSummary(_ summary: DiagnosticSummary) {
        print("""
        Diagnostic Summary:
        - Time Range: \(summary.timeRange)
        - Crashes: \(summary.crashCount)
        - Hangs: \(summary.hangCount)
        - Disk Write Exceptions: \(summary.diskWriteExceptionCount)
        - CPU Exceptions: \(summary.cpuExceptionCount)
        """)
    }
}
