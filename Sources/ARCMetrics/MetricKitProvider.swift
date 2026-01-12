//
//  MetricKitProvider.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import ARCLogger
import Foundation

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
/// ## Topics
///
/// ### Getting Started
/// - ``shared``
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

    // MARK: - Properties

    private let logger = ARCLogger(category: "MetricKit")
    private let processor = MetricKitPayloadProcessor()

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
    /// - Note: Payloads are delivered asynchronously by the system and may not arrive
    ///         immediately after app launch.
    public var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)?

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
    public var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)?

    /// Returns previously received metric summaries from MetricKit's historical data.
    ///
    /// This property accesses `MXMetricManager.pastPayloads` and transforms them into
    /// ``MetricSummary`` objects. Use this to retrieve metrics that were collected
    /// before your callbacks were registered.
    ///
    /// ```swift
    /// let historicalMetrics = MetricKitProvider.shared.pastMetricSummaries
    /// for summary in historicalMetrics {
    ///     print("Historical peak memory: \(summary.peakMemoryUsageMB) MB")
    /// }
    /// ```
    ///
    /// - Note: Returns empty array on macOS (MetricKit unavailable).
    public var pastMetricSummaries: [MetricSummary] {
        #if os(iOS) || os(visionOS)
        return MXMetricManager.shared.pastPayloads.compactMap { payload in
            processor.processMetricPayload(payload)
        }
        #else
        return []
        #endif
    }

    /// Returns previously received diagnostic summaries from MetricKit's historical data.
    ///
    /// This property accesses `MXMetricManager.pastDiagnosticPayloads` and transforms them
    /// into ``DiagnosticSummary`` objects. Use this to retrieve diagnostics that were
    /// collected before your callbacks were registered.
    ///
    /// ```swift
    /// let historicalDiagnostics = MetricKitProvider.shared.pastDiagnosticSummaries
    /// let totalCrashes = historicalDiagnostics.reduce(0) { $0 + $1.crashCount }
    /// ```
    ///
    /// - Note: Returns empty array on macOS (MetricKit unavailable).
    public var pastDiagnosticSummaries: [DiagnosticSummary] {
        #if os(iOS) || os(visionOS)
        return MXMetricManager.shared.pastDiagnosticPayloads.compactMap { payload in
            processor.processDiagnosticPayload(payload)
        }
        #else
        return []
        #endif
    }

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public Methods

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
    /// - Important: You must call this method to begin receiving metric payloads.
    ///              MetricKit will not deliver data unless you subscribe.
    /// - Note: No-op on macOS (MetricKit unavailable).
    public func startCollecting() {
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
    /// This is rarely needed in production apps.
    ///
    /// - Note: No-op on macOS (MetricKit unavailable).
    public func stopCollecting() {
        #if os(iOS) || os(visionOS)
        MXMetricManager.shared.remove(self)
        logger.info("MetricKit collection stopped")
        #else
        logger.warning("MetricKit is not available on this platform")
        #endif
    }
}

// MARK: - MXMetricManagerSubscriber

#if os(iOS) || os(visionOS)
extension MetricKitProvider: MXMetricManagerSubscriber {
    /// Receives metric payloads from MetricKit (memory, CPU, battery, etc.)
    public func didReceive(_ payloads: [MXMetricPayload]) {
        logger.info("Received \(payloads.count) metric payload(s)")

        let summaries = payloads.compactMap { payload in
            processor.processMetricPayload(payload)
        }

        // Log basic info
        for summary in summaries {
            logMetricSummary(summary)
        }

        // Invoke callback for app to handle
        onMetricPayloadsReceived?(summaries)
    }

    /// Receives diagnostic payloads from MetricKit (crashes, hangs, disk writes)
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.warning("Received \(payloads.count) diagnostic payload(s)")

        let summaries = payloads.compactMap { payload in
            processor.processDiagnosticPayload(payload)
        }

        // Log basic info
        for summary in summaries {
            logDiagnosticSummary(summary)
        }

        // Invoke callback
        onDiagnosticPayloadsReceived?(summaries)
    }

    // MARK: - Private Helpers

    private func logMetricSummary(_ summary: MetricSummary) {
        logger.info("""
        Metric Summary:
        - Time Range: \(summary.timeRange)
        - Peak Memory: \(summary.peakMemoryUsageMB) MB
        - Avg CPU: \(summary.averageCPUPercentage)%
        - Hang Time: \(summary.totalHangTimeSeconds)s
        - Launch Time: \(summary.averageLaunchTimeSeconds)s
        """)
    }

    private func logDiagnosticSummary(_ summary: DiagnosticSummary) {
        logger.error("""
        Diagnostic Summary:
        - Time Range: \(summary.timeRange)
        - Crashes: \(summary.crashCount)
        - Hangs: \(summary.hangCount)
        - Disk Write Exceptions: \(summary.diskWriteExceptionCount)
        """)
    }
}
#endif
