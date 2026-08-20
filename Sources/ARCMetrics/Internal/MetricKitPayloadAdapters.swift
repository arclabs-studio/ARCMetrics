//
//  MetricKitPayloadAdapters.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-20.
//

#if os(iOS) || os(visionOS)
import Foundation
import MetricKit

// MARK: - MXMetricPayload

extension MXMetricPayload: MetricPayloadSource {
    var interval: DateInterval {
        // MetricKit does not guarantee ordering across timezone edges; clamp so
        // `DateInterval` never traps on a negative duration.
        DateInterval(start: min(timeStampBegin, timeStampEnd), end: max(timeStampBegin, timeStampEnd))
    }

    var peakMemoryMB: Double? {
        memoryMetrics?.peakMemoryUsage.megabytes
    }

    var averageSuspendedMemoryMB: Double? {
        memoryMetrics?.averageSuspendedMemory.averageMeasurement.megabytes
    }

    var cumulativeCPUTimeSeconds: Double? {
        cpuMetrics?.cumulativeCPUTime.converted(to: .seconds).value
    }

    var cumulativeGPUTimeSeconds: Double? {
        gpuMetrics?.cumulativeGPUTime.converted(to: .seconds).value
    }

    var hangTimeBuckets: [DurationBucket]? {
        applicationResponsivenessMetrics?.histogrammedApplicationHangTime.durationBuckets
    }

    var launchTimeBuckets: [DurationBucket]? {
        applicationLaunchMetrics?.histogrammedTimeToFirstDraw.durationBuckets
    }

    var foregroundTimeSeconds: Double? {
        applicationTimeMetrics?.cumulativeForegroundTime.converted(to: .seconds).value
    }

    var backgroundTimeSeconds: Double? {
        applicationTimeMetrics?.cumulativeBackgroundTime.converted(to: .seconds).value
    }

    var cellularDownloadMB: Double? {
        networkTransferMetrics?.cumulativeCellularDownload.megabytes
    }

    var cellularUploadMB: Double? {
        networkTransferMetrics?.cumulativeCellularUpload.megabytes
    }

    var wifiDownloadMB: Double? {
        networkTransferMetrics?.cumulativeWifiDownload.megabytes
    }

    var wifiUploadMB: Double? {
        networkTransferMetrics?.cumulativeWifiUpload.megabytes
    }

    var cumulativeDiskWritesMB: Double? {
        diskIOMetrics?.cumulativeLogicalWrites.megabytes
    }

    var scrollHitchTimeRatio: Double? {
        animationMetrics?.scrollHitchTimeRatio.value
    }
}

// MARK: - MXDiagnosticPayload

extension MXDiagnosticPayload: DiagnosticPayloadSource {
    var interval: DateInterval {
        DateInterval(start: min(timeStampBegin, timeStampEnd), end: max(timeStampBegin, timeStampEnd))
    }

    var crashes: [CrashDiagnosticSource] {
        (crashDiagnostics ?? []).map { crash in
            CrashDiagnosticSource(exceptionType: crash.exceptionType.map { String(describing: $0) },
                                  signal: crash.signal.map { String(describing: $0) },
                                  terminationReason: crash.terminationReason,
                                  virtualMemoryRegionInfo: crash.virtualMemoryRegionInfo)
        }
    }

    var hangDurationsSeconds: [Double] {
        (hangDiagnostics ?? []).map { $0.hangDuration.converted(to: .seconds).value }
    }

    var diskWriteExceptionCount: Int {
        diskWriteExceptionDiagnostics?.count ?? 0
    }

    var cpuExceptionCount: Int {
        cpuExceptionDiagnostics?.count ?? 0
    }
}

// MARK: - Unit Helpers

extension Measurement where UnitType == UnitInformationStorage {
    fileprivate var megabytes: Double {
        converted(to: .megabytes).value
    }
}

extension MXHistogram where UnitType == UnitDuration {
    /// Flattens the bucket enumerator into plain seconds-based buckets.
    ///
    /// `bucketEnumerator` is an `NSEnumerator` of `Any`, so entries that are not
    /// duration buckets are skipped rather than trapped on.
    fileprivate var durationBuckets: [DurationBucket] {
        bucketEnumerator.compactMap { element in
            guard let bucket = element as? MXHistogramBucket<UnitDuration> else { return nil }
            return DurationBucket(startSeconds: bucket.bucketStart.converted(to: .seconds).value,
                                  endSeconds: bucket.bucketEnd.converted(to: .seconds).value,
                                  count: bucket.bucketCount)
        }
    }
}
#endif
