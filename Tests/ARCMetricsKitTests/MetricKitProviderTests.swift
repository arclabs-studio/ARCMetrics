//
//  MetricKitProviderTests.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import XCTest
@testable import ARCMetricsKit

final class MetricKitProviderTests: XCTestCase {
    func testProviderSingleton() {
        let provider1 = MetricKitProvider.shared
        let provider2 = MetricKitProvider.shared

        XCTAssertTrue(provider1 === provider2, "Provider should be a singleton")
    }

    func testStartCollecting() {
        let provider = MetricKitProvider.shared

        // Should not crash
        XCTAssertNoThrow(provider.startCollecting())
    }

    func testStopCollecting() {
        let provider = MetricKitProvider.shared

        provider.startCollecting()

        // Should not crash
        XCTAssertNoThrow(provider.stopCollecting())
    }

    func testCallbacksAreOptional() {
        let provider = MetricKitProvider.shared

        // Callbacks are optional, should not be required
        XCTAssertNil(provider.onMetricPayloadsReceived)
        XCTAssertNil(provider.onDiagnosticPayloadsReceived)
    }

    func testMetricSummaryDescription() {
        var summary = MetricSummary(timeRange: "Test Range")
        summary.peakMemoryUsageMB = 150.5

        let description = summary.description
        XCTAssertTrue(description.contains("150.5"))
        XCTAssertTrue(description.contains("Test Range"))
    }

    func testDiagnosticSummaryDescription() {
        var summary = DiagnosticSummary(timeRange: "Test Range")
        summary.crashCount = 2
        summary.hangCount = 5

        let description = summary.description
        XCTAssertTrue(description.contains("2"))
        XCTAssertTrue(description.contains("5"))
    }

    func testMetricSummaryCPUPercentageCalculation() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeCPUTimeSeconds = 50
        summary.foregroundTimeSeconds = 100

        XCTAssertEqual(summary.averageCPUPercentage, 50.0, accuracy: 0.1)
    }

    func testMetricSummaryCPUPercentageWithZeroForeground() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeCPUTimeSeconds = 50
        summary.foregroundTimeSeconds = 0

        XCTAssertEqual(summary.averageCPUPercentage, 0)
    }

    func testDiagnosticSummaryCrashInfo() {
        let crashInfo = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_BAD_ACCESS",
            signal: "SIGSEGV",
            terminationReason: "Memory access error",
            virtualMemoryRegionInfo: "0x1000"
        )

        XCTAssertEqual(crashInfo.exceptionType, "EXC_BAD_ACCESS")
        XCTAssertEqual(crashInfo.signal, "SIGSEGV")
    }

    func testDiagnosticSummaryHangInfo() {
        let hangInfo = DiagnosticSummary.HangInfo(duration: 1.5)

        XCTAssertEqual(hangInfo.duration, 1.5, accuracy: 0.01)
    }
}
