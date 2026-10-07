//
//  DeliveryRecorder.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

import Foundation
import struct os.OSAllocatedUnfairLock
@testable import ARCMetrics

/// Records what a backend hands to its `MetricsDelivery`.
final class DeliveryRecorder: Sendable {
    // MARK: - Nested Types

    private struct State {
        var metrics: [MetricSummary] = []
        var diagnostics: [DiagnosticSummary] = []
    }

    // MARK: - Properties

    private let state = OSAllocatedUnfairLock(initialState: State())

    var metrics: [MetricSummary] {
        state.withLock { $0.metrics }
    }

    var diagnostics: [DiagnosticSummary] {
        state.withLock { $0.diagnostics }
    }

    /// A delivery that appends to this recorder.
    var delivery: MetricsDelivery {
        MetricsDelivery(metric: { summary in self.state.withLock { $0.metrics.append(summary) } },
                        diagnostic: { summary in self.state.withLock { $0.diagnostics.append(summary) } })
    }
}
