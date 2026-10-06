//
//  LegacyMXBackend.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

#if os(iOS) || os(visionOS)
import Foundation
import MetricKit
import struct os.OSAllocatedUnfairLock

/// The 1.x backend: an `MXMetricManager` subscriber.
///
/// Used below iOS 27 and on visionOS, where `MetricManager.metricReports` is
/// unavailable. `MXMetricManager` is marked to-be-deprecated in favour of
/// `MetricManager`, but still works and raises no warning at this package's
/// deployment targets.
///
/// Checked `Sendable`: every stored property is a constant, and the delivery
/// target and caches live behind a lock. MetricKit calls the subscriber on a
/// background thread of its choosing.
final class LegacyMXBackend: NSObject, MXMetricManagerSubscriber, MetricsBackend {
    // MARK: - Nested Types

    private struct State {
        var delivery: MetricsDelivery?
        var metricCache: [DateInterval: MetricSummary] = [:]
        var diagnosticCache: [DateInterval: DiagnosticSummary] = [:]
    }

    // MARK: - Properties

    private let logger: any MetricsLogger
    private let processor: MetricKitPayloadProcessor
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// MetricKit's on-device history, transformed once per reporting interval.
    var pastMetricSummaries: [MetricSummary] {
        cachedMetricSummaries(for: MXMetricManager.shared.pastPayloads)
    }

    /// MetricKit's on-device diagnostic history.
    var pastDiagnosticSummaries: [DiagnosticSummary] {
        cachedDiagnosticSummaries(for: MXMetricManager.shared.pastDiagnosticPayloads)
    }

    // MARK: - Initialization

    init(logger: any MetricsLogger) {
        self.logger = logger
        processor = MetricKitPayloadProcessor(logger: logger)
        super.init()
    }

    // MARK: - MetricsBackend

    func start(delivering delivery: MetricsDelivery) {
        state.withLock { $0.delivery = delivery }
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
        state.withLock { $0.delivery = nil }
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        logger.debug("Received \(payloads.count) metric payload(s)")
        let summaries = cachedMetricSummaries(for: payloads)
        // Copy the target out of the lock: never call out while holding it.
        let delivery = state.withLock { $0.delivery }
        for summary in summaries {
            delivery?.metric(summary)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.debug("Received \(payloads.count) diagnostic payload(s)")
        let summaries = cachedDiagnosticSummaries(for: payloads)
        let delivery = state.withLock { $0.delivery }
        for summary in summaries {
            delivery?.diagnostic(summary)
        }
    }
}

// MARK: - Private Helpers

extension LegacyMXBackend {
    /// Transforms `payloads`, reusing any summary already computed for the same
    /// reporting interval.
    private func cachedMetricSummaries(for payloads: [MXMetricPayload]) -> [MetricSummary] {
        payloads.map { payload in
            let interval = payload.interval
            if let cached = state.withLock({ $0.metricCache[interval] }) {
                return cached
            }
            let summary = processor.processMetricPayload(payload)
            state.withLock { $0.metricCache[interval] = summary }
            return summary
        }
    }

    /// Transforms `payloads`, reusing any summary already computed for the same
    /// reporting interval.
    private func cachedDiagnosticSummaries(for payloads: [MXDiagnosticPayload]) -> [DiagnosticSummary] {
        payloads.map { payload in
            let interval = payload.interval
            if let cached = state.withLock({ $0.diagnosticCache[interval] }) {
                return cached
            }
            let summary = processor.processDiagnosticPayload(payload)
            state.withLock { $0.diagnosticCache[interval] = summary }
            return summary
        }
    }
}
#endif
