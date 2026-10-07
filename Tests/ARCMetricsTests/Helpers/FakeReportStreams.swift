//
//  FakeReportStreams.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import struct os.OSAllocatedUnfairLock
@testable import ARCMetrics

/// Stands in for `MetricManager` behind the `MetricReportStreams` seam.
///
/// Each sequence is a single `AsyncStream`, so a backend that started a second
/// reader would trip `AsyncStream`'s one-consumer rule. The access counts make
/// that visible as an assertion rather than a crash.
///
/// A struct on purpose: XCTest realizes every class in the bundle at launch,
/// and a class storing `AsyncStream<MetricReport>` needs `MetricReport`'s
/// metadata to lay itself out, which crashes the runner below iOS 27. Copies
/// share the counts, because `OSAllocatedUnfairLock` is a reference to its
/// storage.
@available(iOS 27, macOS 27, *) struct FakeReportStreams: MetricReportStreams {
    // MARK: - Nested Types

    private struct Counts {
        var metricReportsAccesses = 0
        var diagnosticReportsAccesses = 0
    }

    // MARK: - Properties

    private let metricStream: AsyncStream<MetricReport>
    private let metricContinuation: AsyncStream<MetricReport>.Continuation
    private let diagnosticStream: AsyncStream<DiagnosticReport>
    private let diagnosticContinuation: AsyncStream<DiagnosticReport>.Continuation
    private let counts = OSAllocatedUnfairLock(initialState: Counts())

    var metricReports: AsyncStream<MetricReport> {
        counts.withLock { $0.metricReportsAccesses += 1 }
        return metricStream
    }

    var diagnosticReports: AsyncStream<DiagnosticReport> {
        counts.withLock { $0.diagnosticReportsAccesses += 1 }
        return diagnosticStream
    }

    /// How many readers asked for ``metricReports``.
    var metricReportsAccessCount: Int {
        counts.withLock { $0.metricReportsAccesses }
    }

    /// How many readers asked for ``diagnosticReports``.
    var diagnosticReportsAccessCount: Int {
        counts.withLock { $0.diagnosticReportsAccesses }
    }

    // MARK: - Initialization

    init() {
        (metricStream, metricContinuation) = AsyncStream.makeStream(of: MetricReport.self)
        (diagnosticStream, diagnosticContinuation) = AsyncStream.makeStream(of: DiagnosticReport.self)
    }

    // MARK: - Test Helpers

    /// Delivers `report` as MetricKit would.
    func send(_ report: MetricReport) {
        metricContinuation.yield(report)
    }

    /// Delivers `report` as MetricKit would.
    func send(_ report: DiagnosticReport) {
        diagnosticContinuation.yield(report)
    }

    /// Ends both sequences so the backend's readers return.
    func finish() {
        metricContinuation.finish()
        diagnosticContinuation.finish()
    }
}
#endif
