//
//  MetricManagerBackend.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

// `MetricManager` exists only in the iOS / macOS 27 SDKs, which ship with the
// Swift 6.4 compiler. The macOS CI job builds with an older Xcode.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import struct os.OSAllocatedUnfairLock

/// The iOS / macOS 27 backend: one `MetricManager`, each report sequence read
/// by exactly one task for the backend's whole life.
///
/// Apple warns that two tasks iterating the same sequence each receive a
/// non-deterministic subset of reports. Cancelling a reader does not end it
/// promptly (the sequence is not documented to finish on cancellation, so a
/// cancelled task lingers until the next report and then drops it), which is
/// why the readers are started once and never recreated: ``stop()`` only
/// detaches delivery, exactly like the `MXMetricManager` backend. Reports that
/// arrive while stopped are still kept in history.
///
/// The readers hold the backend weakly; they end at the first report after
/// the backend is released.
///
/// Generic over its report source so tests can drive it with fixtures; the
/// default backend passes a `MetricManager`.
@available(iOS 27, macOS 27, *) final class MetricManagerBackend<Source: MetricReportStreams>: MetricsBackend {
    // MARK: - Nested Types

    private struct State {
        var delivery: MetricsDelivery?
        var isReading = false
        var metricSummaries: [MetricSummary] = []
        var diagnosticSummaries: [DiagnosticSummary] = []
    }

    // MARK: - Properties

    private let source: Source
    private let logger: any MetricsLogger
    private let processor: MetricKitPayloadProcessor
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Summaries received in this process. `MetricManager` exposes no
    /// history of its own.
    var pastMetricSummaries: [MetricSummary] {
        state.withLock { $0.metricSummaries }
    }

    /// Summaries received in this process.
    var pastDiagnosticSummaries: [DiagnosticSummary] {
        state.withLock { $0.diagnosticSummaries }
    }

    // MARK: - Initialization

    init(source: Source, logger: any MetricsLogger) {
        self.source = source
        self.logger = logger
        processor = MetricKitPayloadProcessor(logger: logger)
    }

    // MARK: - MetricsBackend

    func start(delivering delivery: MetricsDelivery) {
        let shouldStartReading = state.withLock { state -> Bool in
            state.delivery = delivery
            defer { state.isReading = true }
            return !state.isReading
        }
        guard shouldStartReading else { return }
        startReaders()
    }

    func stop() {
        state.withLock { $0.delivery = nil }
    }
}

// MARK: - Private Helpers

@available(iOS 27, macOS 27, *) extension MetricManagerBackend {
    /// Starts the two lifetime readers. Called exactly once.
    private func startReaders() {
        let source = source
        Task { [weak self] in
            for await report in source.metricReports {
                guard let self else { return }
                let summary = processor.processMetricPayload(report)
                let delivery = state.withLock { state -> MetricsDelivery? in
                    state.metricSummaries.append(summary)
                    return state.delivery
                }
                // Called outside the lock: never call out while holding it.
                delivery?.metric(summary)
            }
        }
        Task { [weak self] in
            for await report in source.diagnosticReports {
                guard let self else { return }
                guard let diagnosticSource = report.diagnosticSource else {
                    logger.debug("Skipping a diagnostic report this package does not summarise")
                    continue
                }
                let summary = processor.processDiagnosticPayload(diagnosticSource)
                let delivery = state.withLock { state -> MetricsDelivery? in
                    state.diagnosticSummaries.append(summary)
                    return state.delivery
                }
                delivery?.diagnostic(summary)
            }
        }
    }
}
#endif
