//
//  MetricReportAdapters.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

// Same gate as `MetricManagerBackend`: the iOS / macOS 27 SDK types exist only
// with the Swift 6.4 toolchain.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit

// MARK: - MetricReport

/// Reads the full-day aggregate of a `MetricReport`.
///
/// Checked against real reports captured on an iOS 27 device (the fixtures in
/// the test target), except the overall hitch entry, which those captures did
/// not contain: its unit comes from Apple's `HitchTimeRatio` documentation.
/// Units are converted here, so the processor sees the same MB / seconds /
/// ms-per-second values from both backends.
@available(iOS 27, macOS 27, *) extension MetricReport: MetricPayloadSource {
    var interval: DateInterval {
        timeRange
    }

    var peakMemoryMB: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .peakMemory(metric) = result else { return nil }
            return metric.value.megabytes
        }
        #else
        nil
        #endif
    }

    var averageSuspendedMemoryMB: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .suspendedMemory(metric) = result else { return nil }
            return metric.value.average.megabytes
        }
        #else
        nil
        #endif
    }

    var cumulativeCPUTimeSeconds: Double? {
        firstValue { result in
            guard case let .cpuTime(metric) = result else { return nil }
            return metric.value.seconds
        }
    }

    var cumulativeGPUTimeSeconds: Double? {
        firstValue { result in
            guard case let .gpuTime(metric) = result else { return nil }
            return metric.value.seconds
        }
    }

    var hangTimeBuckets: [DurationBucket]? {
        firstValue { result in
            guard case let .hangTime(metric) = result else { return nil }
            return metric.histogram.durationBuckets
        }
    }

    var launchTimeBuckets: [DurationBucket]? {
        firstValue { result in
            guard case let .timeToFirstDraw(metric) = result else { return nil }
            return metric.histogram.durationBuckets
        }
    }

    var foregroundTimeSeconds: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .totalForegroundTime(metric) = result else { return nil }
            return metric.value.seconds
        }
        #else
        nil
        #endif
    }

    var backgroundTimeSeconds: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .totalBackgroundTime(metric) = result else { return nil }
            return metric.value.seconds
        }
        #else
        nil
        #endif
    }

    var cellularDownloadMB: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .totalCellularDownload(metric) = result else { return nil }
            return metric.value.megabytes
        }
        #else
        nil
        #endif
    }

    var cellularUploadMB: Double? {
        #if os(iOS)
        firstValue { result in
            guard case let .totalCellularUpload(metric) = result else { return nil }
            return metric.value.megabytes
        }
        #else
        nil
        #endif
    }

    var wifiDownloadMB: Double? {
        firstValue { result in
            guard case let .totalWiFiDownload(metric) = result else { return nil }
            return metric.value.megabytes
        }
    }

    var wifiUploadMB: Double? {
        firstValue { result in
            guard case let .totalWiFiUpload(metric) = result else { return nil }
            return metric.value.megabytes
        }
    }

    var cumulativeDiskWritesMB: Double? {
        firstValue { result in
            guard case let .logicalDiskWrites(metric) = result else { return nil }
            return metric.value.megabytes
        }
    }

    /// `MetricReport` has no scroll-only hitch metric.
    var scrollHitchTimeRatio: Double? {
        nil
    }

    /// All tracked animations, in ms per second.
    ///
    /// Apple documents `HitchTimeRatio`'s base unit as `"ms per s"`; converting
    /// to it explicitly keeps that true whatever unit a report is encoded in.
    var hitchTimeRatio: Double? {
        firstValue { result in
            guard case let .hitchTime(metric) = result else { return nil }
            return metric.ratio.converted(to: .baseUnit()).value
        }
    }

    // MARK: Private Helpers

    /// The values of the full-day entry, or none.
    ///
    /// `fullDayEntry` is non-optional and its behaviour on an empty array is
    /// undocumented, so it is never asked of one.
    private var fullDayValues: [MetricResult] {
        intervalEntries.isEmpty ? [] : intervalEntries.fullDayEntry.values
    }

    private func firstValue<Value>(_ extract: (MetricResult) -> Value?) -> Value? {
        fullDayValues.lazy.compactMap(extract).first
    }
}

// MARK: - DiagnosticReport

@available(iOS 27, macOS 27, *) extension DiagnosticReport {
    /// The report as a processor input, or `nil` for a diagnostic kind
    /// ``DiagnosticSummary`` has no field for (app launch, memory exception).
    ///
    /// Each `DiagnosticReport` is a single event, so the source holds exactly
    /// one crash, one hang, or one exception.
    var diagnosticSource: (any DiagnosticPayloadSource)? {
        // Clamped like the 1.x adapter, so `DateInterval` never traps.
        let interval = DateInterval(start: min(timeRange.start, timeRange.end),
                                    end: max(timeRange.start, timeRange.end))
        switch result {
        case let .crash(crash):
            return SingleEventDiagnosticSource(interval: interval,
                                               crashes: [CrashDiagnosticSource(exceptionType: crash.exceptionType
                                                       .map { String($0) },
                                                   signal: crash.signal.map { String($0) },
                                                   terminationReason: crash
                                                       .terminationReason?.rawValue,
                                                   virtualMemoryRegionInfo: crash
                                                       .virtualMemoryRegionInfo)])
        case let .hang(hang):
            return SingleEventDiagnosticSource(interval: interval,
                                               hangDurationsSeconds: [hang.hangDuration.seconds])
        case .cpuException:
            return SingleEventDiagnosticSource(interval: interval, cpuExceptionCount: 1)
        case .diskWriteException:
            return SingleEventDiagnosticSource(interval: interval, diskWriteExceptionCount: 1)
        default:
            return nil
        }
    }
}

/// A ``DiagnosticPayloadSource`` holding one `DiagnosticReport`'s event.
struct SingleEventDiagnosticSource: DiagnosticPayloadSource {
    let interval: DateInterval
    var crashes: [CrashDiagnosticSource] = []
    var hangDurationsSeconds: [Double] = []
    var diskWriteExceptionCount = 0
    var cpuExceptionCount = 0
}

// MARK: - Unit Helpers

extension Measurement where UnitType == UnitInformationStorage {
    fileprivate var megabytes: Double {
        converted(to: .megabytes).value
    }
}

extension Measurement where UnitType == UnitDuration {
    fileprivate var seconds: Double {
        converted(to: .seconds).value
    }
}

@available(iOS 27, macOS 27, *) extension Histogram where DimensionType == UnitDuration {
    fileprivate var durationBuckets: [DurationBucket] {
        buckets.map { bucket in
            DurationBucket(startSeconds: bucket.lowerBound.seconds,
                           endSeconds: bucket.upperBound.seconds,
                           count: bucket.count)
        }
    }
}
#endif
