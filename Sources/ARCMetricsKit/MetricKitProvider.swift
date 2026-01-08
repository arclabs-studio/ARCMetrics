//
//  MetricKitProvider.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import ARCLogger
import Foundation
import MetricKit

/// Provider that manages MetricKit data collection for technical app metrics.
///
/// `MetricKitProvider` is a singleton that subscribes to MetricKit's metric and diagnostic payloads.
/// It processes raw MetricKit data and provides simplified summaries through callbacks.
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
/// ### Understanding the Data
/// - <doc:UnderstandingMetrics>
/// - <doc:InstrumentsIntegration>
public final class MetricKitProvider: NSObject, @unchecked Sendable {
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
    public func startCollecting() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit collection started")
    }

    /// Stops collecting metrics from MetricKit.
    ///
    /// Call this method if you need to temporarily pause metric collection.
    /// This is rarely needed in production apps.
    public func stopCollecting() {
        MXMetricManager.shared.remove(self)
        logger.info("MetricKit collection stopped")
    }
}

// MARK: - MXMetricManagerSubscriber

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
