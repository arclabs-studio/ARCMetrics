//
//  MockMetricsCollector.swift
//  ARCMetricsMocks
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import ARCMetrics
import Foundation
import struct os.OSAllocatedUnfairLock

/// A ``MetricsCollecting`` double that delivers only what you simulate.
///
/// MetricKit delivers roughly once a day and never in a unit test, so inject
/// this and push summaries yourself:
///
/// ```swift
/// let collector = MockMetricsCollector()
/// let sut = MetricsLogger(collector: collector)
///
/// collector.simulate(diagnostic: crashSummary)
/// ```
///
/// Simulated summaries reach every current subscriber, exactly like the real
/// collector. Checked `Sendable`: all mutable state lives behind a lock.
public final class MockMetricsCollector: MetricsCollecting {
    // MARK: - Nested Types

    private struct State {
        var isCollecting = false
        var startCollectingCallCount = 0
        var stopCollectingCallCount = 0
    }

    // MARK: - Properties

    private let metricBroadcaster = SummaryBroadcaster<MetricSummary>()
    private let diagnosticBroadcaster = SummaryBroadcaster<DiagnosticSummary>()
    private let state = OSAllocatedUnfairLock(initialState: State())

    public let pastMetricSummaries: [MetricSummary]
    public let pastDiagnosticSummaries: [DiagnosticSummary]

    public var isCollecting: Bool {
        state.withLock { $0.isCollecting }
    }

    /// How many times ``startCollecting()`` was called. Not idempotent, unlike
    /// the real collector, so tests can assert on duplicate calls.
    public var startCollectingCallCount: Int {
        state.withLock { $0.startCollectingCallCount }
    }

    /// How many times ``stopCollecting()`` was called.
    public var stopCollectingCallCount: Int {
        state.withLock { $0.stopCollectingCallCount }
    }

    // MARK: - Initialization

    /// Creates a mock.
    ///
    /// - Parameters:
    ///   - pastMetricSummaries: Returned from ``pastMetricSummaries``.
    ///   - pastDiagnosticSummaries: Returned from ``pastDiagnosticSummaries``.
    public init(pastMetricSummaries: [MetricSummary] = [], pastDiagnosticSummaries: [DiagnosticSummary] = []) {
        self.pastMetricSummaries = pastMetricSummaries
        self.pastDiagnosticSummaries = pastDiagnosticSummaries
    }

    // MARK: - MetricsCollecting

    public func metricSummaries() -> AsyncStream<MetricSummary> {
        metricBroadcaster.subscribe()
    }

    public func diagnosticSummaries() -> AsyncStream<DiagnosticSummary> {
        diagnosticBroadcaster.subscribe()
    }

    public func startCollecting() {
        state.withLock {
            $0.isCollecting = true
            $0.startCollectingCallCount += 1
        }
    }

    public func stopCollecting() {
        state.withLock {
            $0.isCollecting = false
            $0.stopCollectingCallCount += 1
        }
    }

    // MARK: - Simulation

    /// Delivers `metric` to every current ``metricSummaries()`` subscriber.
    public func simulate(metric: MetricSummary) {
        metricBroadcaster.yield(metric)
    }

    /// Delivers `diagnostic` to every current ``diagnosticSummaries()`` subscriber.
    public func simulate(diagnostic: DiagnosticSummary) {
        diagnosticBroadcaster.yield(diagnostic)
    }
}
