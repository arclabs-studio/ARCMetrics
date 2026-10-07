//
//  MetricsCollectorTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation
import Testing
@testable import ARCMetrics

/// Covers `MetricsCollector`'s own responsibilities: forwarding
/// start/stop to the injected `MetricsBackend` idempotently, multicasting
/// whatever the backend delivers to every current subscriber, and exposing
/// the backend's historical data verbatim.
///
/// The motivating case is in `metricSummariesReachTwoConcurrentSubscribers`:
/// v1's `MetricKitProvider` held a single `onMetric` callback, so a second
/// consumer registering silently replaced the first one's delivery channel.
@Suite("MetricsCollector", .tags(.unit), .timeLimit(.minutes(1))) struct MetricsCollectorTests {
    // MARK: - Start/Stop Idempotency

    @Test("startCollecting forwards to the backend exactly once, even when called twice")
    func startCollectingIsIdempotent() {
        // Given
        let backend = FakeMetricsBackend()
        let sut = makeSUT(backend: backend)

        // When
        sut.startCollecting()
        sut.startCollecting()

        // Then
        #expect(backend.startCallCount == 1)
        #expect(sut.isCollecting)
    }

    @Test("stopCollecting forwards to the backend exactly once, even when called twice")
    func stopCollectingIsIdempotent() {
        // Given
        let backend = FakeMetricsBackend()
        let sut = makeSUT(backend: backend)
        sut.startCollecting()

        // When
        sut.stopCollecting()
        sut.stopCollecting()

        // Then
        #expect(backend.stopCallCount == 1)
        #expect(!sut.isCollecting)
    }

    @Test("Starting again after a stop restarts the backend") func startAfterStopRestartsBackend() {
        // Given
        let backend = FakeMetricsBackend()
        let sut = makeSUT(backend: backend)
        sut.startCollecting()
        sut.stopCollecting()

        // When
        sut.startCollecting()

        // Then
        #expect(backend.startCallCount == 2)
        #expect(backend.stopCallCount == 1)
        #expect(sut.isCollecting)
    }

    // MARK: - Multicast

    @Test("A metric summary delivered by the backend reaches two concurrent subscribers")
    func metricSummariesReachTwoConcurrentSubscribers() async {
        // Given — subscribing is synchronous, so both slots are registered
        // before the backend ever delivers anything.
        let backend = FakeMetricsBackend()
        let sut = makeSUT(backend: backend)
        sut.startCollecting()
        let first = sut.metricSummaries()
        let second = sut.metricSummaries()
        let summary = MetricSummary(interval: .fixture())

        // When
        backend.deliver(metric: summary)

        // Then
        async let firstReceived = collectFirst(first, count: 1)
        async let secondReceived = collectFirst(second, count: 1)
        #expect(await firstReceived == [summary])
        #expect(await secondReceived == [summary])
    }

    @Test("A diagnostic summary delivered by the backend reaches two concurrent subscribers")
    func diagnosticSummariesReachTwoConcurrentSubscribers() async {
        // Given
        let backend = FakeMetricsBackend()
        let sut = makeSUT(backend: backend)
        sut.startCollecting()
        let first = sut.diagnosticSummaries()
        let second = sut.diagnosticSummaries()
        let summary = DiagnosticSummary(interval: .fixture())

        // When
        backend.deliver(diagnostic: summary)

        // Then
        async let firstReceived = collectFirst(first, count: 1)
        async let secondReceived = collectFirst(second, count: 1)
        #expect(await firstReceived == [summary])
        #expect(await secondReceived == [summary])
    }

    // MARK: - Stream Lifetime

    @Test("Releasing the collector finishes every open stream") func releaseFinishesStreams() async throws {
        // Given
        var sut: MetricsCollector? = makeSUT(backend: FakeMetricsBackend())
        let metrics = try #require(sut).metricSummaries()
        let diagnostics = try #require(sut).diagnosticSummaries()

        // When
        sut = nil

        // Then — both loops end instead of suspending forever
        #expect(await collectFirst(metrics, count: 1).isEmpty)
        #expect(await collectFirst(diagnostics, count: 1).isEmpty)
    }

    // MARK: - Historical Data

    @Test("pastMetricSummaries is read straight from the backend") func pastMetricSummariesComesFromBackend() {
        // Given
        let expected = [MetricSummary(interval: .fixture())]
        let sut = makeSUT(backend: FakeMetricsBackend(pastMetricSummaries: expected))

        // Then
        #expect(sut.pastMetricSummaries == expected)
    }

    @Test("pastDiagnosticSummaries is read straight from the backend") func pastDiagnosticSummariesComesFromBackend() {
        // Given
        let expected = [DiagnosticSummary(interval: .fixture())]
        let sut = makeSUT(backend: FakeMetricsBackend(pastDiagnosticSummaries: expected))

        // Then
        #expect(sut.pastDiagnosticSummaries == expected)
    }

    // MARK: - Factory

    private func makeSUT(backend: FakeMetricsBackend) -> MetricsCollector {
        MetricsCollector(logger: SilentLogger(), backend: backend)
    }
}
