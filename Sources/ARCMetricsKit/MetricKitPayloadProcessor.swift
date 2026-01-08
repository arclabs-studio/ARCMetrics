//
//  MetricKitPayloadProcessor.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import ARCLogger
import Foundation
import MetricKit

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
            summary.averageMemoryUsageMB = formatBytes(memory.averageSuspendedMemory.averageMeasurement)
        }

        // CPU metrics
        if let cpu = payload.cpuMetrics {
            summary.cumulativeCPUTimeSeconds = cpu.cumulativeCPUTime.converted(to: .seconds).value
        }

        // Application responsiveness metrics (Hangs) - iOS 14+
        if let responsiveness = payload.applicationResponsivenessMetrics {
            summary.totalHangTimeSeconds = responsiveness.histogrammedApplicationHangTime.totalBucketCountsValue
        }

        // Application time metrics
        if let appTime = payload.applicationTimeMetrics {
            summary.foregroundTimeSeconds = appTime.cumulativeForegroundTime.converted(to: .seconds).value
            summary.backgroundTimeSeconds = appTime.cumulativeBackgroundTime.converted(to: .seconds).value
        }

        // Launch metrics
        if let launch = payload.applicationLaunchMetrics {
            let histogram = launch.histogrammedTimeToFirstDraw
            summary.averageLaunchTimeSeconds = calculateHistogramAverage(histogram)
        }

        // Network metrics
        if let network = payload.networkTransferMetrics {
            summary.cellularDownloadMB = formatBytes(network.cumulativeCellularDownload)
            summary.cellularUploadMB = formatBytes(network.cumulativeCellularUpload)
            summary.wifiDownloadMB = formatBytes(network.cumulativeWifiDownload)
            summary.wifiUploadMB = formatBytes(network.cumulativeWifiUpload)
        }

        // GPU metrics
        if let gpu = payload.gpuMetrics {
            summary.cumulativeGPUTimeSeconds = gpu.cumulativeGPUTime.converted(to: .seconds).value
        }

        // Disk I/O metrics
        if let diskIO = payload.diskIOMetrics {
            summary.cumulativeDiskWritesMB = formatBytes(diskIO.cumulativeLogicalWrites)
        }

        // Animation metrics
        if let animation = payload.animationMetrics {
            summary.scrollHitchTimeRatio = animation.scrollHitchTimeRatio.value * 100
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
                    exceptionType: crash.exceptionType.map { String(describing: $0) },
                    signal: crash.signal.map { String(describing: $0) },
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
                    duration: hang.hangDuration.converted(to: .seconds).value
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

    private func formatBytes(_ measurement: Measurement<UnitInformationStorage>) -> Double {
        measurement.converted(to: .megabytes).value
    }

    private func formatBytes(_ measurement: Measurement<UnitInformationStorage>?) -> Double {
        guard let measurement else { return 0 }
        return measurement.converted(to: .megabytes).value
    }

    private func calculateHistogramAverage(_ histogram: MXHistogram<UnitDuration>) -> Double {
        var totalTime: Double = 0
        var totalCount = 0

        for bucket in histogram.bucketEnumerator {
            if let bucket = bucket as? MXHistogramBucket<UnitDuration> {
                let bucketValue = bucket.bucketStart.converted(to: .seconds).value
                totalTime += bucketValue * Double(bucket.bucketCount)
                totalCount += bucket.bucketCount
            }
        }

        return totalCount > 0 ? totalTime / Double(totalCount) : 0
    }
}

// MARK: - MXHistogram Extension

extension MXHistogram where UnitType == UnitDuration {
    /// Calculates the total weighted count from all histogram buckets.
    fileprivate var totalBucketCountsValue: Double {
        var total: Double = 0
        for bucket in bucketEnumerator {
            if let bucket = bucket as? MXHistogramBucket<UnitDuration> {
                total += bucket.bucketStart.converted(to: .seconds).value * Double(bucket.bucketCount)
            }
        }
        return total
    }
}
