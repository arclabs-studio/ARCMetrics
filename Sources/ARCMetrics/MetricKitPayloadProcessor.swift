//
//  MetricKitPayloadProcessor.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import ARCLogger
import Foundation

/// Transforms payload sources into the package's summary models.
///
/// The processor never imports MetricKit. It reads ``MetricPayloadSource`` and
/// ``DiagnosticPayloadSource``, which `MXMetricPayload` / `MXDiagnosticPayload`
/// conform to behind an `#if` in `MetricKitPayloadAdapters.swift`. That seam is
/// what makes this — the aggregation logic, where the bugs are — testable on
/// macOS CI with plain structs, and what lets an iOS 27 `MetricReport` reader
/// slot in beside the legacy one without touching this file.
struct MetricKitPayloadProcessor: Sendable {
    // MARK: - Properties

    private let logger: any Logger

    // MARK: - Initialization

    /// Creates a processor.
    ///
    /// - Parameter logger: Sink for processing diagnostics.
    init(logger: any Logger = ARCLogger(category: "MetricKitProcessor")) {
        self.logger = logger
    }

    // MARK: - Metric Payload Processing

    /// Transforms a metric payload into a summary.
    ///
    /// - Parameter payload: Normalized metric payload.
    /// - Returns: A ``MetricSummary`` with key performance indicators.
    func processMetricPayload(_ payload: some MetricPayloadSource) -> MetricSummary {
        var summary = MetricSummary(interval: payload.interval)

        summary.peakMemoryUsageMB = payload.peakMemoryMB ?? 0
        summary.averageMemoryUsageMB = payload.averageSuspendedMemoryMB ?? 0
        summary.cumulativeCPUTimeSeconds = payload.cumulativeCPUTimeSeconds ?? 0
        summary.cumulativeGPUTimeSeconds = payload.cumulativeGPUTimeSeconds ?? 0
        summary.foregroundTimeSeconds = payload.foregroundTimeSeconds ?? 0
        summary.backgroundTimeSeconds = payload.backgroundTimeSeconds ?? 0
        summary.cellularDownloadMB = payload.cellularDownloadMB ?? 0
        summary.cellularUploadMB = payload.cellularUploadMB ?? 0
        summary.wifiDownloadMB = payload.wifiDownloadMB ?? 0
        summary.wifiUploadMB = payload.wifiUploadMB ?? 0
        summary.cumulativeDiskWritesMB = payload.cumulativeDiskWritesMB ?? 0

        // MetricKit reports the hitch ratio in 0...1; the model is documented as
        // a percentage.
        summary.scrollHitchTimeRatio = (payload.scrollHitchTimeRatio ?? 0) * 100

        summary.totalHangTimeSeconds = Self.weightedTotalSeconds(payload.hangTimeBuckets ?? [])
        summary.averageLaunchTimeSeconds = Self.weightedAverageSeconds(payload.launchTimeBuckets ?? [])

        logger.debug("Processed metric payload for range: \(summary.timeRange)")

        return summary
    }

    // MARK: - Diagnostic Payload Processing

    /// Transforms a diagnostic payload into a summary.
    ///
    /// - Parameter payload: Normalized diagnostic payload.
    /// - Returns: A ``DiagnosticSummary`` with crash and hang information.
    func processDiagnosticPayload(_ payload: some DiagnosticPayloadSource) -> DiagnosticSummary {
        var summary = DiagnosticSummary(interval: payload.interval)

        let crashes = payload.crashes
        summary.crashCount = crashes.count
        summary.crashes = crashes.map { crash in
            DiagnosticSummary.CrashInfo(exceptionType: crash.exceptionType,
                                        signal: crash.signal,
                                        terminationReason: crash.terminationReason,
                                        virtualMemoryRegionInfo: crash.virtualMemoryRegionInfo)
        }

        let hangs = payload.hangDurationsSeconds
        summary.hangCount = hangs.count
        summary.hangs = hangs.map { DiagnosticSummary.HangInfo(duration: $0) }

        summary.diskWriteExceptionCount = payload.diskWriteExceptionCount
        summary.cpuExceptionCount = payload.cpuExceptionCount

        // Only a crash is worth an error-level line; a zero-crash payload is the
        // common case and used to spam the log at `.error` every 24 hours.
        if summary.crashCount > 0 {
            logger.error("Detected \(summary.crashCount) crash(es) in \(summary.timeRange)")
        }
        logger.debug("Processed diagnostic payload for range: \(summary.timeRange)")

        return summary
    }
}

// MARK: - Histogram Arithmetic

extension MetricKitPayloadProcessor {
    /// Total time represented by a histogram, in seconds.
    ///
    /// Weights each bucket by its lower edge, matching MetricKit's own
    /// convention and this package's behaviour before the seam existed.
    static func weightedTotalSeconds(_ buckets: [DurationBucket]) -> Double {
        buckets.reduce(0) { $0 + $1.startSeconds * Double($1.count) }
    }

    /// Mean duration represented by a histogram, in seconds.
    ///
    /// - Returns: `0` for an empty histogram, or one whose buckets are all empty.
    static func weightedAverageSeconds(_ buckets: [DurationBucket]) -> Double {
        let count = buckets.reduce(0) { $0 + $1.count }
        guard count > 0 else { return 0 }
        return weightedTotalSeconds(buckets) / Double(count)
    }
}
