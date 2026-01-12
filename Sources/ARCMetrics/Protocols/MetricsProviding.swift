//
//  MetricsProviding.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import Foundation

/// A protocol defining the interface for metrics collection providers.
///
/// Use this protocol to abstract the metrics collection implementation,
/// enabling dependency injection and easier testing.
///
/// ## Overview
///
/// `MetricsProviding` defines the contract for any metrics provider implementation.
/// The default implementation is ``MetricKitProvider``, which wraps Apple's MetricKit.
///
/// ## Example
///
/// ```swift
/// // Using the default provider
/// let provider: MetricsProviding = MetricKitProvider.shared
/// provider.startCollecting()
///
/// // In tests, use a mock
/// let mockProvider: MetricsProviding = MockMetricsProvider()
/// ```
///
/// ## Topics
///
/// ### Callbacks
/// - ``onMetricPayloadsReceived``
/// - ``onDiagnosticPayloadsReceived``
///
/// ### Collection Control
/// - ``startCollecting()``
/// - ``stopCollecting()``
///
/// ### Historical Data
/// - ``pastMetricSummaries``
/// - ``pastDiagnosticSummaries``
public protocol MetricsProviding: AnyObject, Sendable {
    /// Callback invoked when metric payloads are received.
    ///
    /// MetricKit delivers payloads approximately every 24 hours containing aggregated
    /// metrics about your app's performance.
    var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)? { get set }

    /// Callback invoked when diagnostic payloads are received.
    ///
    /// Diagnostic payloads contain information about crashes, hangs, disk write exceptions,
    /// and other critical events.
    var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)? { get set }

    /// Starts collecting metrics.
    ///
    /// Call this method early in your app's lifecycle to begin receiving metric payloads.
    func startCollecting()

    /// Stops collecting metrics.
    ///
    /// Call this method if you need to temporarily pause metric collection.
    func stopCollecting()

    /// Returns previously received metric summaries since the provider was initialized.
    ///
    /// This provides access to historical metric data that was delivered before
    /// callbacks were registered.
    var pastMetricSummaries: [MetricSummary] { get }

    /// Returns previously received diagnostic summaries since the provider was initialized.
    ///
    /// This provides access to historical diagnostic data that was delivered before
    /// callbacks were registered.
    var pastDiagnosticSummaries: [DiagnosticSummary] { get }
}
