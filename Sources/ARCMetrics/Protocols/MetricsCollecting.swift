//
//  MetricsCollecting.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation

/// The interface for receiving MetricKit metrics and diagnostics.
///
/// Inject this protocol instead of ``MetricsCollector`` so tests can substitute
/// `MockMetricsCollector` from the `ARCMetricsMocks` product.
///
/// ## Overview
///
/// Summaries arrive as `AsyncStream`s. Every call to ``metricSummaries()`` or
/// ``diagnosticSummaries()`` creates a new, independent subscriber that
/// receives every summary delivered from then on, so several consumers (a
/// logger, an exporter) never steal summaries from each other.
///
/// ```swift
/// let collector: any MetricsCollecting = MetricsCollector()
/// collector.startCollecting()
///
/// Task {
///     for await summary in collector.metricSummaries() {
///         print("Peak memory: \(summary.peakMemoryUsageMB) MB")
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Receiving Summaries
/// - ``metricSummaries()``
/// - ``diagnosticSummaries()``
///
/// ### Collection Control
/// - ``startCollecting()``
/// - ``stopCollecting()``
/// - ``isCollecting``
///
/// ### Historical Data
/// - ``pastMetricSummaries``
/// - ``pastDiagnosticSummaries``
public protocol MetricsCollecting: Sendable {
    /// A new stream of metric summaries, roughly one per day.
    ///
    /// No replay: the stream starts empty. Read ``pastMetricSummaries`` for
    /// what arrived earlier.
    func metricSummaries() -> AsyncStream<MetricSummary>

    /// A new stream of diagnostic summaries, one per crash, hang or exception.
    ///
    /// No replay: the stream starts empty. Read ``pastDiagnosticSummaries`` for
    /// what arrived earlier.
    func diagnosticSummaries() -> AsyncStream<DiagnosticSummary>

    /// Starts receiving reports from MetricKit. Idempotent.
    func startCollecting()

    /// Stops receiving reports from MetricKit. Idempotent.
    ///
    /// Open streams stay open and resume delivering after the next
    /// ``startCollecting()``.
    func stopCollecting()

    /// Whether collection is currently running.
    var isCollecting: Bool { get }

    /// Metric summaries delivered before now.
    ///
    /// - Warning: Forwarding these *and* the stream double-counts. Use one or
    ///   the other for a given sink.
    var pastMetricSummaries: [MetricSummary] { get }

    /// Diagnostic summaries delivered before now.
    ///
    /// - Warning: Same double-counting caveat as ``pastMetricSummaries``.
    var pastDiagnosticSummaries: [DiagnosticSummary] { get }
}
