//
//  PayloadSources.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import Foundation

// MARK: - DurationBucket

/// One bucket of a MetricKit duration histogram, in seconds.
///
/// Carrying both edges (rather than MetricKit's `bucketStart` alone) is what
/// lets later percentile work interpolate inside a bucket.
struct DurationBucket: Sendable, Equatable, Hashable {
    let startSeconds: Double
    let endSeconds: Double
    let count: Int
}

// MARK: - MetricPayloadSource

/// Everything ``MetricKitPayloadProcessor`` reads out of a metric payload,
/// stated in plain Swift values.
///
/// `MXMetricPayload` cannot be constructed in a test and does not exist on
/// macOS at all, which is why the processor's transformation logic — the part
/// that actually carries bugs — had no coverage. This protocol is the seam:
/// `MXMetricPayload` conforms to it behind an `#if`, tests conform a plain
/// struct, and the processor never sees MetricKit.
///
/// Units are normalized at the boundary (MB, seconds) so the adapter owns unit
/// conversion and the processor owns aggregation.
///
/// - Note: This is also the iOS 27 migration path. When `MetricManager` /
///   `MetricReport` leave Beta, conform their types here and the processor is
///   unchanged.
protocol MetricPayloadSource {
    /// Period the payload aggregates over.
    var interval: DateInterval { get }

    /// Peak memory usage, in megabytes. `nil` when the payload omits memory metrics.
    var peakMemoryMB: Double? { get }
    /// Average suspended memory, in megabytes.
    var averageSuspendedMemoryMB: Double? { get }

    /// Cumulative CPU time across all threads, in seconds.
    var cumulativeCPUTimeSeconds: Double? { get }
    /// Cumulative GPU time, in seconds.
    var cumulativeGPUTimeSeconds: Double? { get }

    /// Histogram of application hang durations.
    var hangTimeBuckets: [DurationBucket]? { get }
    /// Histogram of time-to-first-draw durations.
    var launchTimeBuckets: [DurationBucket]? { get }

    /// Cumulative foreground time, in seconds.
    var foregroundTimeSeconds: Double? { get }
    /// Cumulative background time, in seconds.
    var backgroundTimeSeconds: Double? { get }

    /// Cumulative cellular download, in megabytes.
    var cellularDownloadMB: Double? { get }
    /// Cumulative cellular upload, in megabytes.
    var cellularUploadMB: Double? { get }
    /// Cumulative Wi-Fi download, in megabytes.
    var wifiDownloadMB: Double? { get }
    /// Cumulative Wi-Fi upload, in megabytes.
    var wifiUploadMB: Double? { get }

    /// Cumulative logical disk writes, in megabytes.
    var cumulativeDiskWritesMB: Double? { get }

    /// Scroll hitch time as a raw ratio in `0...1`, *not* a percentage.
    var scrollHitchTimeRatio: Double? { get }
}

// MARK: - DiagnosticPayloadSource

/// Everything ``MetricKitPayloadProcessor`` reads out of a diagnostic payload.
///
/// Same rationale as ``MetricPayloadSource``.
protocol DiagnosticPayloadSource {
    /// Period the payload aggregates over.
    var interval: DateInterval { get }
    /// One entry per crash diagnostic.
    var crashes: [CrashDiagnosticSource] { get }
    /// Hang durations, in seconds, one per hang diagnostic.
    var hangDurationsSeconds: [Double] { get }
    /// Number of excessive-disk-write diagnostics.
    var diskWriteExceptionCount: Int { get }
    /// Number of excessive-CPU diagnostics.
    var cpuExceptionCount: Int { get }
}

// MARK: - CrashDiagnosticSource

/// The crash fields the processor forwards.
///
/// Deliberately excludes `callStackTree`: tens of kilobytes per crash with no
/// sink in this package.
struct CrashDiagnosticSource: Sendable, Equatable, Hashable {
    let exceptionType: String?
    let signal: String?
    let terminationReason: String?
    let virtualMemoryRegionInfo: String?
}
