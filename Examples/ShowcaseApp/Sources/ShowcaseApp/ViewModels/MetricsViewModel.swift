import ARCMetricsKit
import SwiftUI

/// ViewModel that manages metrics state and handles MetricKit callbacks
@MainActor
final class MetricsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var metricSummaries: [MetricSummary] = []
    @Published var diagnosticSummaries: [DiagnosticSummary] = []
    @Published var isCollecting: Bool = true
    @Published var lastUpdateTime: Date?
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""

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

    init() {
        setupMetricKitCallbacks()
    }

    // MARK: - Setup

    private func setupMetricKitCallbacks() {
        // Register callback for performance metrics
        MetricKitProvider.shared.onMetricPayloadsReceived = { [weak self] summaries in
            Task { @MainActor in
                guard let self else { return }

                print("📊 Received \(summaries.count) metric payload(s)")

                self.metricSummaries.append(contentsOf: summaries)
                self.lastUpdateTime = Date()

                // Show alert for first metrics
                if self.metricSummaries.count == summaries.count {
                    self.showAlert(
                        title: "Metrics Received!",
                        message: "Received your first metric payload with \(summaries.count) summary(ies)"
                    )
                }

                // Log details
                for summary in summaries {
                    self.logMetricSummary(summary)
                }
            }
        }

        // Register callback for diagnostic events
        MetricKitProvider.shared.onDiagnosticPayloadsReceived = { [weak self] summaries in
            Task { @MainActor in
                guard let self else { return }

                print("🔴 Received \(summaries.count) diagnostic payload(s)")

                self.diagnosticSummaries.append(contentsOf: summaries)
                self.lastUpdateTime = Date()

                // Show alert for crashes
                let totalCrashes = summaries.reduce(0) { $0 + $1.crashCount }
                if totalCrashes > 0 {
                    self.showAlert(
                        title: "Crashes Detected",
                        message: "Detected \(totalCrashes) crash(es) in the diagnostic payload"
                    )
                }

                // Log details
                for summary in summaries {
                    self.logDiagnosticSummary(summary)
                }
            }
        }
    }

    // MARK: - Actions

    func toggleCollection() {
        if isCollecting {
            MetricKitProvider.shared.stopCollecting()
            print("⏸️ MetricKit collection stopped")
        } else {
            MetricKitProvider.shared.startCollecting()
            print("▶️ MetricKit collection started")
        }
        isCollecting.toggle()
    }

    func clearAllMetrics() {
        metricSummaries.removeAll()
        diagnosticSummaries.removeAll()
        lastUpdateTime = nil
        print("🗑️ All metrics cleared")
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

    // MARK: - Private Helpers

    private func showAlert(title: String, message: String) {
        alertMessage = "\(title)\n\n\(message)"
        showingAlert = true
    }

    private func logMetricSummary(_ summary: MetricSummary) {
        print("""
        📊 Metric Summary:
        - Time Range: \(summary.timeRange)
        - Peak Memory: \(String(format: "%.1f", summary.peakMemoryUsageMB)) MB
        - Avg CPU: \(String(format: "%.1f", summary.averageCPUPercentage))%
        - GPU Time: \(String(format: "%.2f", summary.cumulativeGPUTimeSeconds))s
        - Disk Writes: \(String(format: "%.1f", summary.cumulativeDiskWritesMB)) MB
        - Scroll Hitch: \(String(format: "%.1f", summary.scrollHitchTimeRatio))%
        - Hang Time: \(String(format: "%.2f", summary.totalHangTimeSeconds))s
        - Launch Time: \(String(format: "%.2f", summary.averageLaunchTimeSeconds))s
        """)
    }

    private func logDiagnosticSummary(_ summary: DiagnosticSummary) {
        print("""
        🔴 Diagnostic Summary:
        - Time Range: \(summary.timeRange)
        - Crashes: \(summary.crashCount)
        - Hangs: \(summary.hangCount)
        - Disk Write Exceptions: \(summary.diskWriteExceptionCount)
        - CPU Exceptions: \(summary.cpuExceptionCount)
        """)
    }
}
