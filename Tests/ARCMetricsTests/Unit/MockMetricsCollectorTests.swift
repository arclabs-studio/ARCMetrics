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
@Suite("MockMetricsCollector", .tags(.unit), .timeLimit(.minutes(1))) struct MockMetricsCollectorTests {
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

    @Test("isCollecting follows the last start or stop call") func isCollectingFollowsCalls() {
        // Given
        let sut = MockMetricsCollector()

        // When / Then
        sut.startCollecting()
        #expect(sut.isCollecting)
        sut.stopCollecting()
        #expect(!sut.isCollecting)
    }

    // MARK: - Stream Lifetime

    @Test("Releasing the mock finishes every open stream, like the real collector")
    func releaseFinishesStreams() async throws {
        // Given
        var sut: MockMetricsCollector? = MockMetricsCollector()
        let metrics = try #require(sut).metricSummaries()
        let diagnostics = try #require(sut).diagnosticSummaries()

        // When
        sut = nil

        // Then
        #expect(await collectFirst(metrics, count: 1).isEmpty)
        #expect(await collectFirst(diagnostics, count: 1).isEmpty)
    }
}
