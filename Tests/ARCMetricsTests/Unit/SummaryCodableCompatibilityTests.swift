//
//  SummaryCodableCompatibilityTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import Foundation
import Testing
@testable import ARCMetrics

/// Guards the hand-written decoders added when ``MetricSummary/interval`` and
/// ``DiagnosticSummary/interval`` were introduced.
///
/// Synthesized `Codable` requires every key to be present, so a consumer that
/// archived summaries under an earlier release would have started failing to
/// decode them. These fixtures are shaped exactly like that older output.
@Suite("Summary Codable compatibility", .tags(.unit, .critical)) struct SummaryCodableCompatibilityTests {
    // MARK: - Metric Summary

    @Test("A pre-interval metric payload still decodes") func decodesLegacyMetricSummary() throws {
        // Given — the v1.0.1 shape: no `interval`, no later-added keys
        let json = Data("""
        {
          "timeRange": "1/1/25, 9:00 AM - 1/2/25, 9:00 AM",
          "peakMemoryUsageMB": 180.5,
          "averageMemoryUsageMB": 42,
          "cumulativeCPUTimeSeconds": 120,
          "totalHangTimeSeconds": 1.5,
          "foregroundTimeSeconds": 600,
          "backgroundTimeSeconds": 90,
          "averageLaunchTimeSeconds": 0.6,
          "cellularDownloadMB": 1.5,
          "cellularUploadMB": 0.5,
          "wifiDownloadMB": 12,
          "wifiUploadMB": 3,
          "cumulativeGPUTimeSeconds": 7,
          "cumulativeDiskWritesMB": 8,
          "scrollHitchTimeRatio": 2.3
        }
        """.utf8)

        // When
        let summary = try JSONDecoder().decode(MetricSummary.self, from: json)

        // Then
        #expect(summary.interval == nil)
        #expect(summary.timeRange == "1/1/25, 9:00 AM - 1/2/25, 9:00 AM")
        #expect(summary.peakMemoryUsageMB == 180.5)
        #expect(summary.scrollHitchTimeRatio == 2.3)
    }

    @Test("A metric payload carrying only timeRange decodes to defaults") func decodesMinimalMetricSummary() throws {
        // Given
        let json = Data(#"{"timeRange": "range"}"#.utf8)

        // When
        let summary = try JSONDecoder().decode(MetricSummary.self, from: json)

        // Then
        #expect(summary.peakMemoryUsageMB == 0)
        #expect(summary.averageLaunchTimeSeconds == 0)
    }

    @Test("A metric payload missing timeRange is rejected") func rejectsMetricSummaryWithoutTimeRange() {
        // Given
        let json = Data(#"{"peakMemoryUsageMB": 12}"#.utf8)

        // When / Then — timeRange is the one non-defaultable field
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MetricSummary.self, from: json)
        }
    }

    @Test("A metric summary round-trips with its interval intact") func metricSummaryRoundTrips() throws {
        // Given
        var summary = MetricSummary(interval: .fixture())
        summary.peakMemoryUsageMB = 180.5
        summary.scrollHitchTimeRatio = 2.3

        // When
        let decoded = try JSONDecoder().decode(MetricSummary.self, from: JSONEncoder().encode(summary))

        // Then
        #expect(decoded == summary)
        #expect(decoded.interval == DateInterval.fixture())
    }

    // MARK: - Diagnostic Summary

    @Test("A pre-interval diagnostic payload still decodes") func decodesLegacyDiagnosticSummary() throws {
        // Given
        let json = Data("""
        {
          "timeRange": "1/1/25, 9:00 AM - 1/2/25, 9:00 AM",
          "crashCount": 1,
          "crashes": [{"exceptionType": "EXC_BAD_ACCESS", "signal": "SIGSEGV"}],
          "hangCount": 2,
          "hangs": [{"duration": 0.4}, {"duration": 1.2}],
          "diskWriteExceptionCount": 3,
          "cpuExceptionCount": 4
        }
        """.utf8)

        // When
        let summary = try JSONDecoder().decode(DiagnosticSummary.self, from: json)

        // Then — absent optional crash fields decode as nil, not as a failure
        #expect(summary.interval == nil)
        #expect(summary.crashCount == 1)
        #expect(summary.crashes.first?.exceptionType == "EXC_BAD_ACCESS")
        #expect(summary.crashes.first?.terminationReason == nil)
        #expect(summary.hangs.map(\.duration) == [0.4, 1.2])
        #expect(summary.diskWriteExceptionCount == 3)
        #expect(summary.cpuExceptionCount == 4)
    }

    @Test("A diagnostic summary round-trips with its interval intact") func diagnosticSummaryRoundTrips() throws {
        // Given
        var summary = DiagnosticSummary(interval: .fixture())
        summary.crashCount = 1
        summary.crashes = [DiagnosticSummary.CrashInfo(exceptionType: "EXC_CRASH",
                                                       signal: "SIGABRT",
                                                       terminationReason: nil,
                                                       virtualMemoryRegionInfo: nil)]

        // When
        let decoded = try JSONDecoder().decode(DiagnosticSummary.self, from: JSONEncoder().encode(summary))

        // Then
        #expect(decoded == summary)
        #expect(decoded.interval == DateInterval.fixture())
    }

    // MARK: - Interval / Display

    @Test("An interval-built summary derives a non-empty display range") func derivesDisplayRange() {
        // Given / When
        let summary = MetricSummary(interval: .fixture())

        // Then — content is locale-dependent, so assert only that it is populated
        #expect(!summary.timeRange.isEmpty)
        #expect(summary.timeRange.contains(" - "))
    }

    @Test("Both summary types render the same interval identically") func summariesShareDisplayFormatting() {
        // Given
        let interval = DateInterval.fixture()

        // When
        let metric = MetricSummary(interval: interval)
        let diagnostic = DiagnosticSummary(interval: interval)

        // Then
        #expect(metric.timeRange == diagnostic.timeRange)
    }
}
