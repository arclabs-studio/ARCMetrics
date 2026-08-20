//
//  StubPayloadSources.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import Foundation
@testable import ARCMetrics

/// Plain stand-in for `MXMetricPayload`, which cannot be constructed in a test
/// and does not exist on macOS. Every field defaults to `nil` so a test states
/// only the metrics it cares about.
struct StubMetricPayload: MetricPayloadSource {
    var interval: DateInterval = .fixture()
    var peakMemoryMB: Double?
    var averageSuspendedMemoryMB: Double?
    var cumulativeCPUTimeSeconds: Double?
    var cumulativeGPUTimeSeconds: Double?
    var hangTimeBuckets: [DurationBucket]?
    var launchTimeBuckets: [DurationBucket]?
    var foregroundTimeSeconds: Double?
    var backgroundTimeSeconds: Double?
    var cellularDownloadMB: Double?
    var cellularUploadMB: Double?
    var wifiDownloadMB: Double?
    var wifiUploadMB: Double?
    var cumulativeDiskWritesMB: Double?
    var scrollHitchTimeRatio: Double?
}

/// Plain stand-in for `MXDiagnosticPayload`.
struct StubDiagnosticPayload: DiagnosticPayloadSource {
    var interval: DateInterval = .fixture()
    var crashes: [CrashDiagnosticSource] = []
    var hangDurationsSeconds: [Double] = []
    var diskWriteExceptionCount = 0
    var cpuExceptionCount = 0
}

extension DateInterval {
    /// A fixed 24-hour window. Fixed rather than `Date()`-relative so failures
    /// are reproducible.
    static func fixture(startingAt start: TimeInterval = 1_700_000_000,
                        durationHours: Double = 24) -> DateInterval {
        DateInterval(start: Date(timeIntervalSince1970: start), duration: durationHours * 3600)
    }
}

extension CrashDiagnosticSource {
    static func fixture(exceptionType: String? = "EXC_BAD_ACCESS",
                        signal: String? = "SIGSEGV",
                        terminationReason: String? = "Namespace SIGNAL",
                        virtualMemoryRegionInfo: String? = nil) -> CrashDiagnosticSource {
        CrashDiagnosticSource(exceptionType: exceptionType,
                              signal: signal,
                              terminationReason: terminationReason,
                              virtualMemoryRegionInfo: virtualMemoryRegionInfo)
    }
}
