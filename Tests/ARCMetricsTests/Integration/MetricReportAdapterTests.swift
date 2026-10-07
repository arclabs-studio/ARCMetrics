//
//  MetricReportAdapterTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

// The iOS 27 `MetricManager` reader is gated to the compiler/SDK pair that
// actually ships `MetricKit.MetricReport`; macOS CI runs Xcode 16, which has
// neither. This suite must be gated identically or it fails to compile there.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import Testing
@testable import ARCMetrics

/// Runs the real `MetricKitPayloadProcessor` pipeline against a `MetricReport`
/// decoded from a fixture captured on an iPhone (iOS 27.0) via Xcode's
/// "Simulate MetricKit Payloads". The oracle is every value below, hand
/// computed from the fixture JSON — independent of the adapter under test.
///
/// `peakMemory`, `suspendedMemory`, foreground/background time and cellular
/// transfer come from `MXMetricResult` cases that do not exist on macOS; how
/// the macOS decoder handles their absence is undocumented, so those fields
/// are asserted only under `#if os(iOS)`.
@Suite("MetricReport adapter", .tags(.unit, .integration)) struct MetricReportAdapterTests {
    @available(iOS 27, macOS 27, *)
    @Test("A real MetricReport maps to the metric summary hand-computed from its fixture")
    func mapsFixtureToSummary() throws {
        // Given
        let report = try loadReport(fixture: "metric-report-simulated")

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processMetricPayload(report)

        // Then — cross-platform fields
        #expect(summary.cumulativeCPUTimeSeconds == 100)
        #expect(summary.cumulativeGPUTimeSeconds == 20)
        #expect(summary.wifiDownloadMB == 60)
        #expect(summary.wifiUploadMB == 50)
        #expect(summary.cumulativeDiskWritesMB == 1.3)
        #expect(abs(summary.totalHangTimeSeconds - 18.0) < 0.000_001)
        #expect(abs(summary.averageLaunchTimeSeconds - 260.0 / 140.0) < 0.000_001)
        #expect(summary.hitchTimeRatio == nil)
        #expect(summary.scrollHitchTimeRatio == nil)
        #expect(summary.interval == DateInterval(start: Date(timeIntervalSinceReferenceDate: 812_844_000),
                                                 end: Date(timeIntervalSinceReferenceDate: 812_930_340)))

        // iOS-only fields — unavailable `MXMetricResult` cases on macOS
        #if os(iOS)
        #expect(summary.peakMemoryUsageMB == 200)
        #expect(summary.averageMemoryUsageMB == 100)
        #expect(summary.foregroundTimeSeconds == 700)
        #expect(summary.backgroundTimeSeconds == 40)
        #expect(summary.cellularDownloadMB == 80)
        #expect(summary.cellularUploadMB == 70)
        #endif
    }

    @available(iOS 27, macOS 27, *)
    @Test("hitchTimeRatio decodes from a report carrying a hitchTimeMetric entry") func decodesHitchTimeRatio() throws {
        // Given — `metric-report-with-hitch.json` is HAND-DERIVED, not a real
        // capture: the simulated payload never included a `hitchTimeMetric`
        // entry, so this adds one following the `<lowerCamelTypeName>` +
        // `{unit,value}` shape observed in every other entry of the real
        // fixture. If this test fails to *decode* (rather than failing the
        // assertion below), the guessed shape is wrong — fix the fixture,
        // never loosen the decode to paper over it.
        let report = try loadReport(fixture: "metric-report-with-hitch")

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processMetricPayload(report)

        // Then
        #expect(summary.hitchTimeRatio == 7.5)
    }

    // MARK: - Factory

    @available(iOS 27, macOS 27, *) private func loadReport(fixture name: String) throws -> MetricReport {
        let url = try #require(Bundle.module.url(forResource: name,
                                                 withExtension: "json",
                                                 subdirectory: "Fixtures/MetricManager"))
        return try JSONDecoder().decode(MetricReport.self, from: Data(contentsOf: url))
    }
}
#endif
