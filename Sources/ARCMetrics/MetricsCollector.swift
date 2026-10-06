//
//  MetricsCollector.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import ARCLogger
import Foundation
import struct os.OSAllocatedUnfairLock

/// Collects MetricKit metrics and diagnostics and publishes them as summaries.
///
/// `MetricsCollector` reads Apple's MetricKit and turns each report into a
/// ``MetricSummary`` or ``DiagnosticSummary``. It uses the newest MetricKit API
/// the device offers: `MetricManager` on iOS and macOS 27, and the
/// `MXMetricManager` subscriber on earlier iOS and on visionOS.
///
/// ## Overview
///
/// Create **one** collector and keep it for the app's lifetime. Apple
/// recommends a single `MetricManager`, so the collector reads MetricKit once
/// and multicasts to as many consumers as you like:
///
/// ```swift
/// let collector = MetricsCollector()
/// collector.startCollecting()
///
/// Task {
///     for await summary in collector.diagnosticSummaries() where summary.crashCount > 0 {
///         logger.error("Crash reported: \(summary)")
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// Checked `Sendable`: every stored property is a constant, and the only
/// mutable state lives behind a lock.
///
/// ## Topics
///
/// ### Creating a Collector
/// - ``init(logger:)``
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
public final class MetricsCollector: MetricsCollecting {
    // MARK: - Properties

    private let logger: any Logger
    private let backend: any MetricsBackend
    private let metricBroadcaster = SummaryBroadcaster<MetricSummary>()
    private let diagnosticBroadcaster = SummaryBroadcaster<DiagnosticSummary>()
    private let collecting = OSAllocatedUnfairLock(initialState: false)

    public var isCollecting: Bool {
        collecting.withLock { $0 }
    }

    /// Metric summaries delivered before now.
    ///
    /// On iOS and macOS 27 this holds only the summaries delivered **in this
    /// process**: `MetricManager` has no equivalent of `MXMetricManager`'s
    /// `pastPayloads`. Below 27 it reads MetricKit's on-device history.
    public var pastMetricSummaries: [MetricSummary] {
        backend.pastMetricSummaries
    }

    /// Diagnostic summaries delivered before now.
    ///
    /// Same platform caveat as ``pastMetricSummaries``.
    public var pastDiagnosticSummaries: [DiagnosticSummary] {
        backend.pastDiagnosticSummaries
    }

    // MARK: - Initialization

    /// Creates a collector backed by the newest MetricKit API available.
    ///
    /// - Parameter logger: Destination for the collector's own log lines.
    public convenience init(logger: any Logger = ARCLogger(category: "MetricKit")) {
        self.init(logger: logger, backend: Self.makeDefaultBackend(logger: logger))
    }

    /// Creates a collector over an explicit backend. The seam tests use.
    init(logger: any Logger, backend: any MetricsBackend) {
        self.logger = logger
        self.backend = backend
    }

    // MARK: - MetricsCollecting

    public func metricSummaries() -> AsyncStream<MetricSummary> {
        metricBroadcaster.subscribe()
    }

    public func diagnosticSummaries() -> AsyncStream<DiagnosticSummary> {
        diagnosticBroadcaster.subscribe()
    }

    /// Starts receiving reports from MetricKit.
    ///
    /// Idempotent: a second call while already collecting is ignored. App
    /// composition roots are sometimes rebuilt, and a duplicate subscription
    /// would deliver every report twice.
    public func startCollecting() {
        let metricBroadcaster = metricBroadcaster
        let diagnosticBroadcaster = diagnosticBroadcaster
        let delivery = MetricsDelivery(metric: { metricBroadcaster.yield($0) },
                                       diagnostic: { diagnosticBroadcaster.yield($0) })
        // The backend call happens inside the lock so concurrent start/stop
        // calls reach the backend in the same order they flip the flag.
        let didStart = collecting.withLock { isCollecting -> Bool in
            guard !isCollecting else { return false }
            isCollecting = true
            backend.start(delivering: delivery)
            return true
        }
        guard didStart else {
            logger.debug("MetricKit collection already started; ignoring duplicate call")
            return
        }
        logger.info("MetricKit collection started")
    }

    /// Stops receiving reports from MetricKit. Idempotent.
    public func stopCollecting() {
        let didStop = collecting.withLock { isCollecting -> Bool in
            guard isCollecting else { return false }
            isCollecting = false
            backend.stop()
            return true
        }
        guard didStop else { return }
        logger.info("MetricKit collection stopped")
    }
}
