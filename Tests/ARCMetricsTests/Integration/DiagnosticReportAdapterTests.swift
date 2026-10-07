//
//  DiagnosticReportAdapterTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

// See MetricReportAdapterTests.swift for why this gate must match production.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import Testing
@testable import ARCMetrics

/// Each fixture here is one real `DiagnosticReport`, captured on an iPhone
/// (iOS 27.0) via Xcode's "Simulate MetricKit Payloads" — one report, one
/// diagnostic event. The oracle for every assertion is hand-read off the
/// fixture JSON (crash signal/exception numbers, hang duration in ms),
/// independent of `diagnosticSource` and of `MetricKitPayloadProcessor`.
@Suite("DiagnosticReport adapter", .tags(.unit, .integration)) struct DiagnosticReportAdapterTests {
    @available(iOS 27, macOS 27, *)
    @Test("A crash diagnostic report maps to exactly one crash with the fixture's fields")
    func mapsCrashDiagnostic() throws {
        // Given
        let report = try loadReport(fixture: "diagnostic-crashDiagnostic-simulated")
        let source = try #require(report.diagnosticSource)

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processDiagnosticPayload(source)

        // Then
        #expect(summary.crashCount == 1)
        let crash = try #require(summary.crashes.first)
        #expect(crash.exceptionType == "1")
        #expect(crash.signal == "11")
        #expect(crash.terminationReason == "Namespace SIGNAL, Code 0xb")
        #expect(crash.virtualMemoryRegionInfo == DiagnosticReportAdapterTests.crashVMRegionInfo)
    }

    @available(iOS 27, macOS 27, *)
    @Test("A hang diagnostic report maps to exactly one hang of the fixture's duration")
    func mapsHangDiagnostic() throws {
        // Given
        let report = try loadReport(fixture: "diagnostic-hangDiagnostic-simulated")
        let source = try #require(report.diagnosticSource)

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processDiagnosticPayload(source)

        // Then — fixture's hangDuration is 20000 ms
        #expect(summary.hangCount == 1)
        #expect(summary.hangs.first?.duration == 20.0)
    }

    @available(iOS 27, macOS 27, *)
    @Test("A CPU exception diagnostic report counts as exactly one CPU exception")
    func mapsCPUExceptionDiagnostic() throws {
        // Given
        let report = try loadReport(fixture: "diagnostic-cpuExceptionDiagnostic-simulated")
        let source = try #require(report.diagnosticSource)

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processDiagnosticPayload(source)

        // Then
        #expect(summary.cpuExceptionCount == 1)
        #expect(summary.crashCount == 0)
        #expect(summary.hangCount == 0)
    }

    @available(iOS 27, macOS 27, *)
    @Test("A disk write exception diagnostic report counts as exactly one disk write exception")
    func mapsDiskWriteExceptionDiagnostic() throws {
        // Given
        let report = try loadReport(fixture: "diagnostic-diskWriteExceptionDiagnostic-simulated")
        let source = try #require(report.diagnosticSource)

        // When
        let summary = MetricKitPayloadProcessor(logger: SilentLogger()).processDiagnosticPayload(source)

        // Then
        #expect(summary.diskWriteExceptionCount == 1)
        #expect(summary.crashCount == 0)
        #expect(summary.hangCount == 0)
    }

    @available(iOS 27, macOS 27, *)
    @Test("An app launch diagnostic report has no mapped source") func appLaunchDiagnosticHasNoSource() throws {
        // Given / When
        let report = try loadReport(fixture: "diagnostic-appLaunchDiagnostic-simulated")

        // Then — not every diagnostic type this package tracks; no summary to emit
        #expect(report.diagnosticSource == nil)
    }

    // MARK: - Factory

    @available(iOS 27, macOS 27, *) private func loadReport(fixture name: String) throws -> DiagnosticReport {
        let url = try #require(Bundle.module.url(forResource: name,
                                                 withExtension: "json",
                                                 subdirectory: "Fixtures/MetricManager"))
        return try JSONDecoder().decode(DiagnosticReport.self, from: Data(contentsOf: url))
    }

    // MARK: - Fixture Constants

    /// `virtualMemoryRegionInfo` from `diagnostic-crashDiagnostic-simulated.json`,
    /// extracted verbatim (JSON's escaped `\/` already resolved to `/`).
    private static let crashVMRegionInfo =
        "0 is not in any region.  Bytes before following region: 4000000000 REGION TYPE" +
        "                      START - END             [ VSIZE] PRT/MAX SHRMOD  REGION DETAIL " +
        "UNUSED SPACE AT START ---> __TEXT                 0000000000000000-0000000000000000 " +
        "[   32K] r-x/r-x SM=COW  ...pp/Test"
}
#endif
