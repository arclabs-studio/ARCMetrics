//
//  MockMetricsCollectorTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import ARCMetrics
import ARCMetricsMocks
import Foundation
import Testing

/// `MockMetricsCollector` is the public test double consumers of
/// `ARCMetrics` get from `ARCMetricsMocks` — this suite is written against
/// `MetricsCollecting`, the same protocol a consumer's own code would depend
/// on, never against mock-only internals.
@Suite("MockMetricsCollector", .tags(.unit)) struct MockMetricsCollectorTests {
    // MARK: - Simulation Reaches Every Subscriber

    @Test("A simulated metric reaches two concurrent subscribers") func simulateMetricReachesTwoSubscribers() async {
        // Given
        let sut = MockMetricsCollector()
        let first = sut.metricSummaries()
        let second = sut.metricSummaries()
        let summary = MetricSummary(timeRange: "Simulated")

        // When
        sut.simulate(metric: summary)

        // Then
        async let firstReceived = collectFirst(first, count: 1)
        async let secondReceived = collectFirst(second, count: 1)
        #expect(await firstReceived == [summary])
        #expect(await secondReceived == [summary])
    }

    @Test("A simulated diagnostic reaches two concurrent subscribers")
    func simulateDiagnosticReachesTwoSubscribers() async {
        // Given
        let sut = MockMetricsCollector()
        let first = sut.diagnosticSummaries()
        let second = sut.diagnosticSummaries()
        let summary = DiagnosticSummary(timeRange: "Simulated")

        // When
        sut.simulate(diagnostic: summary)

        // Then
        async let firstReceived = collectFirst(first, count: 1)
        async let secondReceived = collectFirst(second, count: 1)
        #expect(await firstReceived == [summary])
        #expect(await secondReceived == [summary])
    }

    // MARK: - Call Counts

    @Test("startCollecting/stopCollecting call counts track exactly how many times they were called")
    func callCountsTrackInvocations() {
        // Given
        let sut = MockMetricsCollector()

        // When
        sut.startCollecting()
        sut.startCollecting()
        sut.stopCollecting()

        // Then
        #expect(sut.startCollectingCallCount == 2)
        #expect(sut.stopCollectingCallCount == 1)
    }
}
