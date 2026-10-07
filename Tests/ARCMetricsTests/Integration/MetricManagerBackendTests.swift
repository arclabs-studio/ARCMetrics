//
//  MetricManagerBackendTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

// See MetricReportAdapterTests.swift for why this gate must match production.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import Testing
@testable import ARCMetrics

/// The iOS / macOS 27 backend, driven by real report fixtures through a fake
/// `MetricReportStreams` in place of `MetricManager`.
///
/// The contract under test comes from Apple's warning that two tasks reading
/// the same report sequence each get a random subset of reports: the backend
/// reads each sequence exactly once for its whole life, and `stop()` only
/// detaches delivery.
@Suite("MetricManagerBackend", .tags(.integration, .critical), .timeLimit(.minutes(1)))
struct MetricManagerBackendTests {
    @available(iOS 27, macOS 27, *)
    @Test("A report received while started is delivered and kept in history")
    func deliversAndRecordsWhileStarted() async throws {
        // Given
        let streams = FakeReportStreams()
        defer { streams.finish() }
        let sut = makeSUT(streams: streams)
        let recorder = DeliveryRecorder()
        sut.start(delivering: recorder.delivery)

        // When
        try streams.send(ReportFixtures.metricReport("metric-report-simulated"))
        await waitUntil { recorder.metrics.count == 1 }

        // Then — 100 s of CPU time, read off the fixture
        #expect(recorder.metrics.map(\.cumulativeCPUTimeSeconds) == [100])
        #expect(sut.pastMetricSummaries.map(\.cumulativeCPUTimeSeconds) == [100])
    }

    @available(iOS 27, macOS 27, *)
    @Test("stop detaches delivery but reports keep landing in history")
    func stopDetachesDeliveryButKeepsHistory() async throws {
        // Given
        let streams = FakeReportStreams()
        defer { streams.finish() }
        let sut = makeSUT(streams: streams)
        let recorder = DeliveryRecorder()
        sut.start(delivering: recorder.delivery)

        // When
        sut.stop()
        try streams.send(ReportFixtures.metricReport("metric-report-simulated"))
        await waitUntil { sut.pastMetricSummaries.count == 1 }

        // Then
        #expect(sut.pastMetricSummaries.count == 1)
        #expect(recorder.metrics.isEmpty)
    }

    @available(iOS 27, macOS 27, *)
    @Test("start, stop, start reads each report sequence exactly once") func restartReusesTheReaders() async throws {
        // Given
        let streams = FakeReportStreams()
        defer { streams.finish() }
        let sut = makeSUT(streams: streams)
        let recorder = DeliveryRecorder()

        // When
        sut.start(delivering: DeliveryRecorder().delivery)
        sut.stop()
        sut.start(delivering: recorder.delivery)
        try streams.send(ReportFixtures.metricReport("metric-report-simulated"))
        try streams.send(ReportFixtures.diagnosticReport("diagnostic-crashDiagnostic-simulated"))
        await waitUntil { recorder.metrics.count == 1 && recorder.diagnostics.count == 1 }

        // Then — the latest delivery receives, and nothing read a sequence twice
        #expect(recorder.metrics.count == 1)
        #expect(recorder.diagnostics.count == 1)
        #expect(streams.metricReportsAccessCount == 1)
        #expect(streams.diagnosticReportsAccessCount == 1)
    }

    @available(iOS 27, macOS 27, *)
    @Test("A diagnostic report this package does not summarise is skipped, not recorded")
    func skipsUnmappedDiagnostics() async throws {
        // Given
        let streams = FakeReportStreams()
        defer { streams.finish() }
        let sut = makeSUT(streams: streams)
        let recorder = DeliveryRecorder()
        sut.start(delivering: recorder.delivery)

        // When — the sequence is ordered, so once the crash lands the app
        // launch report before it has been handled
        try streams.send(ReportFixtures.diagnosticReport("diagnostic-appLaunchDiagnostic-simulated"))
        try streams.send(ReportFixtures.diagnosticReport("diagnostic-crashDiagnostic-simulated"))
        await waitUntil { recorder.diagnostics.count == 1 }

        // Then
        #expect(recorder.diagnostics.map(\.crashCount) == [1])
        #expect(sut.pastDiagnosticSummaries.map(\.crashCount) == [1])
    }

    @available(iOS 27, macOS 27, *)
    @Test("The readers do not keep the backend alive") func readersDoNotRetainBackend() {
        // Given
        let streams = FakeReportStreams()
        defer { streams.finish() }
        var sut: MetricManagerBackend<FakeReportStreams>? = makeSUT(streams: streams)
        sut?.start(delivering: DeliveryRecorder().delivery)
        weak let released = sut

        // When
        sut = nil

        // Then
        #expect(released == nil)
    }

    // MARK: - Factory

    @available(iOS 27, macOS 27, *)
    private func makeSUT(streams: FakeReportStreams) -> MetricManagerBackend<FakeReportStreams> {
        MetricManagerBackend(source: streams, logger: SilentLogger())
    }
}
#endif
