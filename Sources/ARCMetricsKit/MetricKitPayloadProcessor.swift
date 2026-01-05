import Foundation
import MetricKit
import ARCLogger

/// Processes raw MetricKit payloads into simplified summary models.
///
/// This internal class handles the complex MetricKit API and extracts the most
/// relevant metrics into easy-to-use `MetricSummary` and `DiagnosticSummary` objects.
final class MetricKitPayloadProcessor {

    private let logger = ARCLogger(category: "MetricKitProcessor")

    // MARK: - Metric Payload Processing

    /// Processes a metric payload into a simplified summary.
    ///
    /// - Parameter payload: Raw MetricKit payload containing aggregated metrics
    /// - Returns: A simplified `MetricSummary` with key performance indicators
    func processMetricPayload(_ payload: MXMetricPayload) -> MetricSummary {
        var summary = MetricSummary(
            timeRange: formatDateRange(
                start: payload.timeStampBegin,
                end: payload.timeStampEnd
            )
        )

        // Memory metrics
        if let memory = payload.memoryMetrics {
            summary.peakMemoryUsageMB = formatBytes(memory.peakMemoryUsage)
            summary.averageMemoryUsageMB = formatBytes(memory.averageSuspendedMemory?.averageMeasurement)
        }

        // CPU metrics
        if let cpu = payload.cpuMetrics {
            summary.cumulativeCPUTimeSeconds = cpu.cumulativeCPUTime.value(as: .seconds)
        }

        // Display metrics (Hangs)
        if let display = payload.displayMetrics {
            summary.totalHangTimeSeconds = display.totalHangTime?.value(as: .seconds) ?? 0
        }

        // Application time metrics
        if let appTime = payload.applicationTimeMetrics {
            summary.foregroundTimeSeconds = appTime.cumulativeForegroundTime.value(as: .seconds)
            summary.backgroundTimeSeconds = appTime.cumulativeBackgroundTime.value(as: .seconds)
        }

        // Launch metrics
        if let launch = payload.applicationLaunchMetrics {
            if let histogram = launch.histogrammedTimeToFirstDraw {
                summary.averageLaunchTimeSeconds = calculateHistogramAverage(histogram)
            }
        }

        // Network metrics
        if let network = payload.networkTransferMetrics {
            summary.cellularDownloadMB = formatBytes(network.cumulativeCellularDownload)
            summary.cellularUploadMB = formatBytes(network.cumulativeCellularUpload)
            summary.wifiDownloadMB = formatBytes(network.cumulativeWifiDownload)
            summary.wifiUploadMB = formatBytes(network.cumulativeWifiUpload)
        }

        logger.debug("Processed metric payload for range: \(summary.timeRange)")

        return summary
    }

    // MARK: - Diagnostic Payload Processing

    /// Processes a diagnostic payload into a simplified summary.
    ///
    /// - Parameter payload: Raw MetricKit diagnostic payload
    /// - Returns: A simplified `DiagnosticSummary` with crash and hang information
    func processDiagnosticPayload(_ payload: MXDiagnosticPayload) -> DiagnosticSummary {
        var summary = DiagnosticSummary(
            timeRange: formatDateRange(
                start: payload.timeStampBegin,
                end: payload.timeStampEnd
            )
        )

        // Crash diagnostics
        if let crashes = payload.crashDiagnostics {
            summary.crashCount = crashes.count
            summary.crashes = crashes.compactMap { crash in
                DiagnosticSummary.CrashInfo(
                    exceptionType: crash.exceptionType?.rawValue,
                    signal: crash.signal?.rawValue,
                    terminationReason: crash.terminationReason,
                    virtualMemoryRegionInfo: crash.virtualMemoryRegionInfo
                )
            }
            logger.error("Detected \(crashes.count) crash(es)")
        }

        // Hang diagnostics
        if let hangs = payload.hangDiagnostics {
            summary.hangCount = hangs.count
            summary.hangs = hangs.compactMap { hang in
                DiagnosticSummary.HangInfo(
                    duration: hang.hangDuration.value(as: .seconds)
                )
            }
            logger.warning("Detected \(hangs.count) hang(s)")
        }

        // Disk write exceptions
        if let diskWrites = payload.diskWriteExceptionDiagnostics {
            summary.diskWriteExceptionCount = diskWrites.count
        }

        // CPU exceptions
        if let cpuExceptions = payload.cpuExceptionDiagnostics {
            summary.cpuExceptionCount = cpuExceptions.count
        }

        logger.debug("Processed diagnostic payload for range: \(summary.timeRange)")

        return summary
    }

    // MARK: - Helpers

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func formatBytes(_ measurement: Measurement<UnitInformationStorage>?) -> Double {
        guard let measurement = measurement else { return 0 }
        return measurement.converted(to: .megabytes).value
    }

    private func calculateHistogramAverage(_ histogram: MXHistogram<UnitDuration>) -> Double {
        var totalTime: Double = 0
        var totalCount: Int = 0

        for bucket in histogram.bucketEnumerator {
            if let bucket = bucket as? MXHistogramBucket<UnitDuration> {
                let bucketValue = bucket.bucketStart.value(as: .seconds)
                totalTime += bucketValue * Double(bucket.bucketCount)
                totalCount += bucket.bucketCount
            }
        }

        return totalCount > 0 ? totalTime / Double(totalCount) : 0
    }
}
