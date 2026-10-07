//
//  FakeMetricsBackend.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation
import struct os.OSAllocatedUnfairLock
@testable import ARCMetrics

/// Test double for the `MetricsBackend` seam `MetricsCollector` is built on.
///
/// Stands in for whatever actually subscribes to MetricKit, letting a test
/// drive delivery (`deliver(metric:)` / `deliver(diagnostic:)`) without a real
/// `MXMetricManager` or the iOS 27 `MetricManager`. All state lives behind a
/// single lock, so the type is *checked* `Sendable` — no `@unchecked` escape —
/// matching the house rule the production mocks in `ARCMetricsMocks` follow.
final class FakeMetricsBackend: MetricsBackend, Sendable {
    // MARK: - Nested Types

    private struct State {
        var delivery: MetricsDelivery?
        var startCallCount = 0
        var stopCallCount = 0
        var pastMetricSummaries: [MetricSummary]
        var pastDiagnosticSummaries: [DiagnosticSummary]
    }

    // MARK: - Properties

    private let state: OSAllocatedUnfairLock<State>

    var startCallCount: Int {
        state.withLock { $0.startCallCount }
    }

    var stopCallCount: Int {
        state.withLock { $0.stopCallCount }
    }

    var pastMetricSummaries: [MetricSummary] {
        state.withLock { $0.pastMetricSummaries }
    }

    var pastDiagnosticSummaries: [DiagnosticSummary] {
        state.withLock { $0.pastDiagnosticSummaries }
    }

    // MARK: - Initialization

    init(pastMetricSummaries: [MetricSummary] = [], pastDiagnosticSummaries: [DiagnosticSummary] = []) {
        state = OSAllocatedUnfairLock(initialState: State(pastMetricSummaries: pastMetricSummaries,
                                                          pastDiagnosticSummaries: pastDiagnosticSummaries))
    }

    // MARK: - MetricsBackend

    func start(delivering delivery: MetricsDelivery) {
        state.withLock {
            $0.startCallCount += 1
            $0.delivery = delivery
        }
    }

    func stop() {
        state.withLock {
            $0.stopCallCount += 1
            $0.delivery = nil
        }
    }

    // MARK: - Test Helpers

    /// Simulates the backend delivering a metric summary, as it would after
    /// MetricKit hands it a payload.
    ///
    /// A no-op before `start(delivering:)` has registered a delivery — mirrors
    /// production, where nothing is wired up until collection starts.
    func deliver(metric: MetricSummary) {
        let callback = state.withLock { $0.delivery?.metric }
        callback?(metric)
    }

    /// Simulates the backend delivering a diagnostic summary.
    func deliver(diagnostic: DiagnosticSummary) {
        let callback = state.withLock { $0.delivery?.diagnostic }
        callback?(diagnostic)
    }
}
