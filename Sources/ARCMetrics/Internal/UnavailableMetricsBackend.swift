//
//  UnavailableMetricsBackend.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

/// The backend for platforms without a usable MetricKit (macOS before 27).
///
/// Delivers nothing, so the collector's contract still holds everywhere.
struct UnavailableMetricsBackend: MetricsBackend {
    let logger: any MetricsLogger

    func start(delivering _: MetricsDelivery) {
        logger.warning("MetricKit is not available on this platform")
    }

    func stop() {}

    var pastMetricSummaries: [MetricSummary] {
        []
    }

    var pastDiagnosticSummaries: [DiagnosticSummary] {
        []
    }
}
