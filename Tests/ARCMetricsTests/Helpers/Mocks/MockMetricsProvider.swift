//
//  MockMetricsProvider.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import Foundation
@testable import ARCMetrics

/// A mock implementation of `MetricsProviding` for testing purposes.
///
/// Use this mock to test code that depends on metrics collection without
/// requiring actual MetricKit payloads.
///
/// ```swift
/// let mock = MockMetricsProvider()
/// mock.simulateMetricPayload(MetricSummary(timeRange: "Test"))
/// ```
final class MockMetricsProvider: MetricsProviding, @unchecked Sendable {
    // MARK: - Properties

    var onMetricPayloadsReceived: (@Sendable ([MetricSummary]) -> Void)?
    var onDiagnosticPayloadsReceived: (@Sendable ([DiagnosticSummary]) -> Void)?

    private(set) var isCollecting = false
    private(set) var startCollectingCallCount = 0
    private(set) var stopCollectingCallCount = 0

    private var _pastMetricSummaries: [MetricSummary] = []
    private var _pastDiagnosticSummaries: [DiagnosticSummary] = []

    var pastMetricSummaries: [MetricSummary] {
        _pastMetricSummaries
    }

    var pastDiagnosticSummaries: [DiagnosticSummary] {
        _pastDiagnosticSummaries
    }

    // MARK: - MetricsProviding

    func startCollecting() {
        isCollecting = true
        startCollectingCallCount += 1
    }

    func stopCollecting() {
        isCollecting = false
        stopCollectingCallCount += 1
    }

    // MARK: - Test Helpers

    /// Simulates receiving metric payloads.
    ///
    /// - Parameter summaries: The metric summaries to deliver
    func simulateMetricPayload(_ summaries: [MetricSummary]) {
        _pastMetricSummaries.append(contentsOf: summaries)
        onMetricPayloadsReceived?(summaries)
    }

    /// Simulates receiving a single metric payload.
    ///
    /// - Parameter summary: The metric summary to deliver
    func simulateMetricPayload(_ summary: MetricSummary) {
        simulateMetricPayload([summary])
    }

    /// Simulates receiving diagnostic payloads.
    ///
    /// - Parameter summaries: The diagnostic summaries to deliver
    func simulateDiagnosticPayload(_ summaries: [DiagnosticSummary]) {
        _pastDiagnosticSummaries.append(contentsOf: summaries)
        onDiagnosticPayloadsReceived?(summaries)
    }

    /// Simulates receiving a single diagnostic payload.
    ///
    /// - Parameter summary: The diagnostic summary to deliver
    func simulateDiagnosticPayload(_ summary: DiagnosticSummary) {
        simulateDiagnosticPayload([summary])
    }

    /// Resets all state and call counts.
    func reset() {
        isCollecting = false
        startCollectingCallCount = 0
        stopCollectingCallCount = 0
        _pastMetricSummaries = []
        _pastDiagnosticSummaries = []
        onMetricPayloadsReceived = nil
        onDiagnosticPayloadsReceived = nil
    }
}

// MARK: - Test Data Generators

extension MockMetricsProvider {
    /// Creates a sample metric summary for testing.
    static func sampleMetricSummary(
        timeRange: String = "Test Range",
        peakMemory: Double = 150.0,
        cpuTime: Double = 50.0,
        foregroundTime: Double = 100.0
    ) -> MetricSummary {
        var summary = MetricSummary(timeRange: timeRange)
        summary.peakMemoryUsageMB = peakMemory
        summary.cumulativeCPUTimeSeconds = cpuTime
        summary.foregroundTimeSeconds = foregroundTime
        return summary
    }

    /// Creates a sample diagnostic summary for testing.
    static func sampleDiagnosticSummary(
        timeRange: String = "Test Range",
        crashCount: Int = 0,
        hangCount: Int = 0
    ) -> DiagnosticSummary {
        var summary = DiagnosticSummary(timeRange: timeRange)
        summary.crashCount = crashCount
        summary.hangCount = hangCount
        return summary
    }

    /// Creates a sample crash info for testing.
    static func sampleCrashInfo(
        exceptionType: String = "EXC_BAD_ACCESS",
        signal: String = "SIGSEGV"
    ) -> DiagnosticSummary.CrashInfo {
        DiagnosticSummary.CrashInfo(
            exceptionType: exceptionType,
            signal: signal,
            terminationReason: "Test termination",
            virtualMemoryRegionInfo: "0x1000"
        )
    }

    /// Creates a sample hang info for testing.
    static func sampleHangInfo(duration: Double = 1.5) -> DiagnosticSummary.HangInfo {
        DiagnosticSummary.HangInfo(duration: duration)
    }
}
