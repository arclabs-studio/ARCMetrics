//
//  MetricKitProvider.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import ARCLogger
import Foundation

// Targeted import: a bare `import os` would make `Logger` ambiguous against
// ARCLogger's own `Logger` protocol.
import struct os.OSAllocatedUnfairLock

#if os(iOS) || os(visionOS)
import MetricKit
#endif

/// Provider that manages MetricKit data collection for technical app metrics.
///
/// `MetricKitProvider` is a singleton that subscribes to MetricKit's metric and diagnostic payloads.
/// It processes raw MetricKit data and provides simplified summaries through callbacks.
///
/// ## Overview
///
/// Use ``MetricKitProvider`` to receive performance metrics and diagnostics from Apple's MetricKit
/// framework. The provider handles subscription management and transforms raw payloads into
/// easy-to-use ``MetricSummary`` and ``DiagnosticSummary`` objects.
///
/// ## Thread Safety
///
/// MetricKit delivers payloads on a background thread of its choosing, while
/// callbacks are typically assigned from the main thread during launch. All
/// mutable state therefore lives behind a single lock. A callback is *copied
/// out* of the lock before being invoked, so a handler that re-enters the
/// provider cannot deadlock.
///
/// ## Topics
///
/// ### Getting Started
/// - ``shared``
/// - ``configure(logger:)``
/// - ``startCollecting()``
/// - ``stopCollecting()``
///
/// ### Receiving Metrics
/// - ``onMetricPayloadsReceived``
/// - ``onDiagnosticPayloadsReceived``
///
/// ### Historical Data
/// - ``pastMetricSummaries``
/// - ``pastDiagnosticSummaries``
///
/// ### Understanding the Data
/// - <doc:UnderstandingMetrics>
/// - <doc:InstrumentsIntegration>
public final class MetricKitProvider: NSObject, @unchecked Sendable, MetricsProviding {
    // MARK: - Singleton

    /// Shared singleton instance of the MetricKit provider.
    ///
    /// Use this instance to start collecting metrics and register callbacks.
    ///
    /// ```swift
    /// MetricKitProvider.shared.startCollecting()
    /// ```
    public static let shared = MetricKitProvider()

    // MARK: - Nested Types

    /// All mutable provider state, guarded by a single lock.
    private struct State {
        var logger: any Logger = ARCLogger(category: "MetricKit")
        var onMetric: (@Sendable ([MetricSummary]) -> Void)?
        var onDiagnostic: (@Sendable ([DiagnosticSummary]) -> Void)?
        var isCollecting = false
        var metricCache: [DateInterval: MetricSummary] = [:]
        var diagnosticCache: [DateInterval: DiagnosticSummary] = [:]
    }

    // MARK: - Properties

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Callback invoked when metric payloads are received from MetricKit.
    ///
    /// MetricKit delivers payloads approximately every 24 hours containing aggregated
    /// metrics about your app's performance.
    ///
    /// ```swift
    /// MetricKitProvider.shared.onMetricPayloadsReceived = { summaries in
    ///     for summary in summaries {
    ///         print("Peak memory: \(summary.peakMemoryUsageMB) MB")
    ///         // Send to your analytics backend
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Invoked on MetricKit's delivery thread, not the main thread.
    /// - Note: Payloads are delivered asynchronously by the system and may not arrive
    ///         immediately after app launch.
    public var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)? {
        get { state.withLock { $0.onMetric } }
        set { state.withLock { $0.onMetric = newValue } }
    }

    /// Callback invoked when diagnostic payloads are received from MetricKit.
    ///
    /// Diagnostic payloads contain information about crashes, hangs, disk write exceptions,
    /// and other critical events.
    ///
    /// ```swift
    /// MetricKitProvider.shared.onDiagnosticPayloadsReceived = { summaries in
    ///     for summary in summaries {
    ///         if summary.crashCount > 0 {
    ///             // Alert your crash reporting system
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Important: Invoked on MetricKit's delivery thread, not the main thread.
    public var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)? {
        get { state.withLock { $0.onDiagnostic } }
        set { state.withLock { $0.onDiagnostic = newValue } }
    }

    /// Whether the provider is currently subscribed to MetricKit.
    public var isCollecting: Bool {
        state.withLock { $0.isCollecting }
    }

    /// Returns previously received metric summaries from MetricKit's historical data.
    ///
    /// Reads `MXMetricManager.pastPayloads` and transforms them into
    /// ``MetricSummary`` objects, memoizing per reporting interval so repeated
    /// reads do not reprocess the whole history.
    ///
    /// - Warning: Consumers that also handle ``onMetricPayloadsReceived`` will
    ///   double-count if they forward these too. Use one or the other.
    /// - Note: Returns an empty array on macOS (MetricKit unavailable).
    public var pastMetricSummaries: [MetricSummary] {
        #if os(iOS) || os(visionOS)
        return cachedMetricSummaries(for: MXMetricManager.shared.pastPayloads)
        #else
        return []
        #endif
    }

    /// Returns previously received diagnostic summaries from MetricKit's historical data.
    ///
    /// Reads `MXMetricManager.pastDiagnosticPayloads` and transforms them into
    /// ``DiagnosticSummary`` objects, memoized per reporting interval.
    ///
    /// - Warning: Same double-counting caveat as ``pastMetricSummaries``.
    /// - Note: Returns an empty array on macOS (MetricKit unavailable).
    public var pastDiagnosticSummaries: [DiagnosticSummary] {
        #if os(iOS) || os(visionOS)
        return cachedDiagnosticSummaries(for: MXMetricManager.shared.pastDiagnosticPayloads)
        #else
        return []
        #endif
    }

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Replaces the logger used for collection and payload processing.
    ///
    /// - Parameter logger: Destination for the provider's own log lines.
    /// - Important: Call this *before* ``startCollecting()``. Payload processing
    ///   captures the logger at delivery time, so a later call still takes
    ///   effect, but start-up lines would be lost.
    public func configure(logger: any Logger) {
        state.withLock { $0.logger = logger }
    }

    /// Starts collecting metrics with MetricKit.
    ///
    /// Call this method early in your app's lifecycle, typically in your `App` initializer
    /// or `AppDelegate.didFinishLaunching`.
    ///
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///         MetricKitProvider.shared.startCollecting()
    ///     }
    /// }
    /// ```
    ///
    /// Idempotent: a second call while already collecting is ignored. This
    /// matters because app composition roots are sometimes rebuilt (a retry
    /// after a persistence-container failure, for instance), and a duplicate
    /// `MXMetricManager.add(_:)` would deliver every payload twice.
    ///
    /// - Important: You must call this method to begin receiving metric payloads.
    ///              MetricKit will not deliver data unless you subscribe.
    /// - Note: No-op on macOS (MetricKit unavailable).
    public func startCollecting() {
        // The state transition is platform-independent so the idempotency
        // contract holds — and stays testable — everywhere; only the
        // subscription itself is gated.
        let (shouldStart, logger) = state.withLock { state -> (Bool, any Logger) in
            let shouldStart = !state.isCollecting
            state.isCollecting = true
            return (shouldStart, state.logger)
        }
        guard shouldStart else {
            logger.debug("MetricKit collection already started; ignoring duplicate call")
            return
        }

        #if os(iOS) || os(visionOS)
        MXMetricManager.shared.add(self)
        logger.info("MetricKit collection started")
        #else
        logger.warning("MetricKit is not available on this platform")
        #endif
    }

    /// Stops collecting metrics from MetricKit.
    ///
    /// Call this method if you need to temporarily pause metric collection.
    /// This is rarely needed in production apps. Idempotent, mirroring
    /// ``startCollecting()``.
    ///
    /// - Note: No-op on macOS (MetricKit unavailable).
    public func stopCollecting() {
        let (shouldStop, logger) = state.withLock { state -> (Bool, any Logger) in
            let shouldStop = state.isCollecting
            state.isCollecting = false
            return (shouldStop, state.logger)
        }
        guard shouldStop else { return }

        #if os(iOS) || os(visionOS)
        MXMetricManager.shared.remove(self)
        logger.info("MetricKit collection stopped")
        #else
        logger.warning("MetricKit is not available on this platform")
        #endif
    }
}

// MARK: - Internal Helpers

extension MetricKitProvider {
    /// The configured logger, copied out of the lock.
    var currentLogger: any Logger {
        state.withLock { $0.logger }
    }

    /// Transforms `payloads`, reusing any summary already computed for the same
    /// reporting interval.
    func cachedMetricSummaries(for payloads: [some MetricPayloadSource]) -> [MetricSummary] {
        let processor = MetricKitPayloadProcessor(logger: currentLogger)
        return payloads.map { payload in
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
    func cachedDiagnosticSummaries(for payloads: [some DiagnosticPayloadSource]) -> [DiagnosticSummary] {
        let processor = MetricKitPayloadProcessor(logger: currentLogger)
        return payloads.map { payload in
            let interval = payload.interval
            if let cached = state.withLock({ $0.diagnosticCache[interval] }) {
                return cached
            }
            let summary = processor.processDiagnosticPayload(payload)
            state.withLock { $0.diagnosticCache[interval] = summary }
            return summary
        }
    }

    /// Copies the metric callback out of the lock, then invokes it.
    ///
    /// Never call out while holding the lock: a handler that touches the
    /// provider (assigning a callback, reading `isCollecting`) would deadlock on
    /// a non-recursive unfair lock.
    func deliver(metricSummaries: [MetricSummary]) {
        let callback = state.withLock { $0.onMetric }
        callback?(metricSummaries)
    }

    /// Copies the diagnostic callback out of the lock, then invokes it.
    func deliver(diagnosticSummaries: [DiagnosticSummary]) {
        let callback = state.withLock { $0.onDiagnostic }
        callback?(diagnosticSummaries)
    }
}

// MARK: - MXMetricManagerSubscriber

#if os(iOS) || os(visionOS)
extension MetricKitProvider: MXMetricManagerSubscriber {
    /// Receives metric payloads from MetricKit (memory, CPU, GPU, etc.)
    public func didReceive(_ payloads: [MXMetricPayload]) {
        let logger = currentLogger
        logger.debug("Received \(payloads.count) metric payload(s)")

        let summaries = cachedMetricSummaries(for: payloads)
        for summary in summaries {
            logMetricSummary(summary, to: logger)
        }

        deliver(metricSummaries: summaries)
    }

    /// Receives diagnostic payloads from MetricKit (crashes, hangs, disk writes)
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let logger = currentLogger
        logger.debug("Received \(payloads.count) diagnostic payload(s)")

        let summaries = cachedDiagnosticSummaries(for: payloads)
        for summary in summaries {
            logDiagnosticSummary(summary, to: logger)
        }

        deliver(diagnosticSummaries: summaries)
    }

    // MARK: - Private Helpers

    private func logMetricSummary(_ summary: MetricSummary, to logger: any Logger) {
        logger.debug("""
        Metric Summary:
        - Time Range: \(summary.timeRange)
        - Peak Memory: \(summary.peakMemoryUsageMB) MB
        - Avg CPU: \(summary.averageCPUPercentage)%
        - Hang Time: \(summary.totalHangTimeSeconds)s
        - Launch Time: \(summary.averageLaunchTimeSeconds)s
        """)
    }

    private func logDiagnosticSummary(_ summary: DiagnosticSummary, to logger: any Logger) {
        let message = """
        Diagnostic Summary:
        - Time Range: \(summary.timeRange)
        - Crashes: \(summary.crashCount)
        - Hangs: \(summary.hangCount)
        - Disk Write Exceptions: \(summary.diskWriteExceptionCount)
        """
        // `.error` is reserved for payloads that actually contain a crash; a
        // clean 24-hour window is not an error condition.
        if summary.crashCount > 0 {
            logger.error(message)
        } else {
            logger.debug(message)
        }
    }
}
#endif
