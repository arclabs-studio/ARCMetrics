//
//  MetricKitProviderStateTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import Foundation
import Testing
@testable import ARCMetrics

/// Covers the provider's locked state: idempotent collection, callback
/// delivery, and interval-keyed memoization.
///
/// `MetricKitProvider` is a singleton, so these run `.serialized` and each test
/// restores the collection flag it found.
@Suite("MetricKitProvider state", .tags(.unit), .serialized) struct MetricKitProviderStateTests {
    // MARK: - Collection Lifecycle

    @Test("startCollecting flips the collecting flag") func startFlipsFlag() {
        // Given
        let sut = makeSUT()
        defer { sut.stopCollecting() }

        // When
        sut.startCollecting()

        // Then
        #expect(sut.isCollecting)
    }

    @Test("A duplicate startCollecting is ignored") func startIsIdempotent() {
        // Given — the composition root can be rebuilt on a container-recovery
        // retry, which would otherwise double-subscribe and double-deliver.
        let sut = makeSUT()
        let logger = RecordingLogger()
        sut.configure(logger: logger)
        defer { sut.stopCollecting() }
        sut.startCollecting()

        // When
        sut.startCollecting()
        sut.startCollecting()

        // Then
        #expect(sut.isCollecting)
        #expect(logger.entries(at: .debug).contains { $0.message.contains("already started") })
    }

    @Test("stopCollecting is symmetric and idempotent") func stopIsSymmetric() {
        // Given
        let sut = makeSUT()
        sut.startCollecting()

        // When
        sut.stopCollecting()
        sut.stopCollecting()

        // Then
        #expect(!sut.isCollecting)
    }

    @Test("start after stop subscribes again") func startAfterStopResubscribes() {
        // Given
        let sut = makeSUT()
        defer { sut.stopCollecting() }
        sut.startCollecting()
        sut.stopCollecting()

        // When
        sut.startCollecting()

        // Then
        #expect(sut.isCollecting)
    }

    // MARK: - Callback Delivery

    @Test("Metric summaries reach the registered callback") func deliversMetricSummaries() {
        // Given
        let sut = makeSUT()
        let received = Collector<[MetricSummary]>()
        sut.onMetricPayloadsReceived = { received.append($0) }
        defer { sut.onMetricPayloadsReceived = nil }
        let summaries = [MetricSummary(interval: .fixture())]

        // When
        sut.deliver(metricSummaries: summaries)

        // Then
        #expect(received.values.count == 1)
        #expect(received.values.first?.first?.interval == DateInterval.fixture())
    }

    @Test("Diagnostic summaries reach the registered callback") func deliversDiagnosticSummaries() {
        // Given
        let sut = makeSUT()
        let received = Collector<[DiagnosticSummary]>()
        sut.onDiagnosticPayloadsReceived = { received.append($0) }
        defer { sut.onDiagnosticPayloadsReceived = nil }

        // When
        sut.deliver(diagnosticSummaries: [DiagnosticSummary(interval: .fixture())])

        // Then
        #expect(received.values.count == 1)
    }

    @Test("Delivery with no callback registered is a no-op") func deliveryWithoutCallback() {
        // Given
        let sut = makeSUT()
        sut.onMetricPayloadsReceived = nil

        // When / Then — must not trap
        sut.deliver(metricSummaries: [MetricSummary(interval: .fixture())])
    }

    @Test("A callback that re-enters the provider does not deadlock") func reentrantCallbackDoesNotDeadlock() {
        // Given — the callback is copied out of the lock before it is invoked,
        // so touching provider state from inside it is safe.
        let sut = makeSUT()
        let observed = Collector<Bool>()
        sut.onMetricPayloadsReceived = { _ in
            observed.append(MetricKitProvider.shared.isCollecting)
            MetricKitProvider.shared.onDiagnosticPayloadsReceived = { _ in }
        }
        defer {
            sut.onMetricPayloadsReceived = nil
            sut.onDiagnosticPayloadsReceived = nil
            sut.stopCollecting()
        }
        sut.startCollecting()

        // When
        sut.deliver(metricSummaries: [])

        // Then
        #expect(observed.values == [true])
    }

    // MARK: - Memoization

    @Test("Summaries are memoized per reporting interval") func memoizesByInterval() {
        // Given
        let sut = makeSUT()
        let payload = StubMetricPayload(interval: .fixture(startingAt: 1_800_000_000), peakMemoryMB: 111)

        // When — the same interval is processed twice
        let first = sut.cachedMetricSummaries(for: [payload])
        let second = sut.cachedMetricSummaries(for: [payload])

        // Then
        #expect(first == second)
        #expect(first.first?.peakMemoryUsageMB == 111)
    }

    @Test("Distinct intervals get distinct summaries") func distinctIntervalsAreNotConflated() {
        // Given
        let sut = makeSUT()
        let early = StubMetricPayload(interval: .fixture(startingAt: 1_810_000_000), peakMemoryMB: 100)
        let late = StubMetricPayload(interval: .fixture(startingAt: 1_820_000_000), peakMemoryMB: 200)

        // When
        let summaries = sut.cachedMetricSummaries(for: [early, late])

        // Then
        #expect(summaries.map(\.peakMemoryUsageMB) == [100, 200])
    }

    @Test("Diagnostic summaries are memoized per reporting interval") func memoizesDiagnosticsByInterval() {
        // Given
        let sut = makeSUT()
        let payload = StubDiagnosticPayload(interval: .fixture(startingAt: 1_830_000_000),
                                            crashes: [.fixture()])

        // When
        let first = sut.cachedDiagnosticSummaries(for: [payload])
        let second = sut.cachedDiagnosticSummaries(for: [payload])

        // Then
        #expect(first == second)
        #expect(first.first?.crashCount == 1)
    }

    // MARK: - Factory

    private func makeSUT() -> MetricKitProvider {
        let provider = MetricKitProvider.shared
        provider.stopCollecting()
        provider.configure(logger: SilentLogger())
        return provider
    }
}

// MARK: - Test Doubles

/// Minimal thread-safe accumulator. Callbacks fire on MetricKit's thread in
/// production, so the test double must not assume the main thread either.
private final class Collector<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Element] = []

    var values: [Element] {
        lock.withLock { storage }
    }

    func append(_ element: Element) {
        lock.withLock { storage.append(element) }
    }
}
