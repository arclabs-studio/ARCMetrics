//
//  MetricsBackend.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation

/// Where a backend hands each summary it produces.
struct MetricsDelivery: Sendable {
    let metric: @Sendable (MetricSummary) -> Void
    let diagnostic: @Sendable (DiagnosticSummary) -> Void
}

/// One MetricKit API generation, reduced to the summaries it produces.
///
/// ``MetricsCollector`` picks a backend at runtime: `MetricManager` on
/// iOS/macOS 27, the `MXMetricManager` subscriber below that. Tests inject a
/// fake. Backends own payload processing and history; the collector owns
/// fan-out and the start/stop state machine.
protocol MetricsBackend: Sendable {
    /// Begins delivering summaries. Called at most once per stop/start cycle,
    /// under the collector's lock: must not call back into the collector.
    func start(delivering delivery: MetricsDelivery)

    /// Stops delivering. Called only after ``start(delivering:)``, under the
    /// collector's lock.
    func stop()

    /// Metric summaries this backend can report from before now.
    var pastMetricSummaries: [MetricSummary] { get }

    /// Diagnostic summaries this backend can report from before now.
    var pastDiagnosticSummaries: [DiagnosticSummary] { get }
}
