//
//  MetricReportStreams.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-07.
//

// See MetricManagerBackend.swift for the gate.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import MetricKit

/// The two report sequences ``MetricManagerBackend`` reads.
///
/// `MetricManager` is the only production conformer. The seam exists because
/// `MetricManager` delivers nothing in a test process, so tests feed decoded
/// report fixtures through a fake instead.
@available(iOS 27, macOS 27, *) protocol MetricReportStreams: Sendable {
    associatedtype MetricReports: AsyncSequence<MetricReport, Never>
    associatedtype DiagnosticReports: AsyncSequence<DiagnosticReport, Never>

    /// Metric reports, roughly one per day.
    var metricReports: MetricReports { get }

    /// Diagnostic reports, one per event.
    var diagnosticReports: DiagnosticReports { get }
}

@available(iOS 27, macOS 27, *) extension MetricManager: MetricReportStreams {}
#endif
