//
//  DefaultMetricsBackend.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

#if compiler(>=6.4) && (os(iOS) || os(macOS))
import MetricKit
#endif

extension MetricsCollector {
    /// Picks the newest MetricKit API this device offers.
    ///
    /// - iOS / macOS 27: `MetricManager`. Gated on the Swift 6.4 compiler as
    ///   well, because older Xcodes ship an SDK without `MetricManager` at all.
    /// - iOS / visionOS below that: the `MXMetricManager` subscriber. visionOS
    ///   stays on it even at 27, where `MetricManager.metricReports` and
    ///   `logHandle(category:)` are unavailable.
    /// - macOS below 27: nothing, as in 1.x.
    static func makeDefaultBackend(logger: any MetricsLogger) -> any MetricsBackend {
        #if compiler(>=6.4) && (os(iOS) || os(macOS))
        if #available(iOS 27, macOS 27, *) {
            return MetricManagerBackend(source: MetricManager(), logger: logger)
        }
        #endif

        #if os(iOS) || os(visionOS)
        return LegacyMXBackend(logger: logger)
        #else
        return UnavailableMetricsBackend(logger: logger)
        #endif
    }
}
