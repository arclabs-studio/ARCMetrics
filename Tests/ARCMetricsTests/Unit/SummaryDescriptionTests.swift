//
//  SummaryDescriptionTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

import Foundation
import Testing
@testable import ARCMetrics

/// Both summaries hand-write `CustomStringConvertible`, which is what lands
/// in logs. Each test pins the labelled field it prints, so a reordered or
/// relabelled line fails instead of passing on a stray digit.
@Suite("Summary descriptions", .tags(.unit)) struct SummaryDescriptionTests {
    @Test("A metric summary prints its range and one-decimal peak memory") func metricSummaryDescription() {
        // Given
        var summary = MetricSummary(timeRange: "Test Range")
        summary.peakMemoryUsageMB = 150.54

        // When
        let description = summary.description

        // Then
        #expect(description.contains("timeRange: Test Range"))
        #expect(description.contains("peak=150.5MB"))
    }

    @Test("A diagnostic summary prints each count against its label") func diagnosticSummaryDescription() {
        // Given
        var summary = DiagnosticSummary(timeRange: "Test Range")
        summary.crashCount = 2
        summary.hangCount = 5

        // When
        let description = summary.description

        // Then
        #expect(description.contains("timeRange: Test Range"))
        #expect(description.contains("crashes: 2"))
        #expect(description.contains("hangs: 5"))
        #expect(description.contains("cpuExceptions: 0"))
    }
}
