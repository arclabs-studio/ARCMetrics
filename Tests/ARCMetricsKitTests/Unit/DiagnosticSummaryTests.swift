//
//  DiagnosticSummaryTests.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import XCTest
@testable import ARCMetricsKit

final class DiagnosticSummaryTests: XCTestCase {
    // MARK: - Initialization Tests

    func testInitialization() {
        let summary = DiagnosticSummary(timeRange: "Test Range")

        XCTAssertEqual(summary.timeRange, "Test Range")
        XCTAssertEqual(summary.crashCount, 0)
        XCTAssertEqual(summary.hangCount, 0)
        XCTAssertEqual(summary.diskWriteExceptionCount, 0)
        XCTAssertEqual(summary.cpuExceptionCount, 0)
        XCTAssertTrue(summary.crashes.isEmpty)
        XCTAssertTrue(summary.hangs.isEmpty)
    }

    // MARK: - CrashInfo Tests

    func testCrashInfoInitialization() {
        let crashInfo = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_BAD_ACCESS",
            signal: "SIGSEGV",
            terminationReason: "Memory access error",
            virtualMemoryRegionInfo: "0x1000"
        )

        XCTAssertEqual(crashInfo.exceptionType, "EXC_BAD_ACCESS")
        XCTAssertEqual(crashInfo.signal, "SIGSEGV")
        XCTAssertEqual(crashInfo.terminationReason, "Memory access error")
        XCTAssertEqual(crashInfo.virtualMemoryRegionInfo, "0x1000")
    }

    func testCrashInfoWithNilValues() {
        let crashInfo = DiagnosticSummary.CrashInfo(
            exceptionType: nil,
            signal: nil,
            terminationReason: nil,
            virtualMemoryRegionInfo: nil
        )

        XCTAssertNil(crashInfo.exceptionType)
        XCTAssertNil(crashInfo.signal)
        XCTAssertNil(crashInfo.terminationReason)
        XCTAssertNil(crashInfo.virtualMemoryRegionInfo)
    }

    // MARK: - HangInfo Tests

    func testHangInfoInitialization() {
        let hangInfo = DiagnosticSummary.HangInfo(duration: 1.5)

        XCTAssertEqual(hangInfo.duration, 1.5, accuracy: 0.01)
    }

    func testHangInfoSeverityLevels() {
        let minor = DiagnosticSummary.HangInfo(duration: 0.3)
        let moderate = DiagnosticSummary.HangInfo(duration: 0.7)
        let severe = DiagnosticSummary.HangInfo(duration: 2.0)

        XCTAssertLessThan(minor.duration, 0.5, "Minor hang should be < 0.5s")
        XCTAssertGreaterThanOrEqual(moderate.duration, 0.5, "Moderate hang should be >= 0.5s")
        XCTAssertGreaterThan(severe.duration, 1.0, "Severe hang should be > 1.0s")
    }

    // MARK: - Codable Tests

    func testDiagnosticSummaryCodable() throws {
        var summary = DiagnosticSummary(timeRange: "Test Range")
        summary.crashCount = 2
        summary.hangCount = 3
        summary.diskWriteExceptionCount = 1
        summary.cpuExceptionCount = 1

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DiagnosticSummary.self, from: data)

        XCTAssertEqual(decoded.timeRange, summary.timeRange)
        XCTAssertEqual(decoded.crashCount, summary.crashCount)
        XCTAssertEqual(decoded.hangCount, summary.hangCount)
        XCTAssertEqual(decoded.diskWriteExceptionCount, summary.diskWriteExceptionCount)
        XCTAssertEqual(decoded.cpuExceptionCount, summary.cpuExceptionCount)
    }

    func testCrashInfoCodable() throws {
        let crashInfo = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_BAD_ACCESS",
            signal: "SIGSEGV",
            terminationReason: "Test",
            virtualMemoryRegionInfo: "0x1000"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(crashInfo)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DiagnosticSummary.CrashInfo.self, from: data)

        XCTAssertEqual(decoded.exceptionType, crashInfo.exceptionType)
        XCTAssertEqual(decoded.signal, crashInfo.signal)
    }

    func testHangInfoCodable() throws {
        let hangInfo = DiagnosticSummary.HangInfo(duration: 1.5)

        let encoder = JSONEncoder()
        let data = try encoder.encode(hangInfo)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DiagnosticSummary.HangInfo.self, from: data)

        XCTAssertEqual(decoded.duration, hangInfo.duration, accuracy: 0.01)
    }

    // MARK: - Equatable Tests

    func testDiagnosticSummaryEquatable() {
        var summary1 = DiagnosticSummary(timeRange: "Test Range")
        summary1.crashCount = 2

        var summary2 = DiagnosticSummary(timeRange: "Test Range")
        summary2.crashCount = 2

        var summary3 = DiagnosticSummary(timeRange: "Test Range")
        summary3.crashCount = 5

        XCTAssertEqual(summary1, summary2)
        XCTAssertNotEqual(summary1, summary3)
    }

    func testCrashInfoEquatable() {
        let crash1 = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_BAD_ACCESS",
            signal: "SIGSEGV",
            terminationReason: "Test",
            virtualMemoryRegionInfo: nil
        )

        let crash2 = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_BAD_ACCESS",
            signal: "SIGSEGV",
            terminationReason: "Test",
            virtualMemoryRegionInfo: nil
        )

        let crash3 = DiagnosticSummary.CrashInfo(
            exceptionType: "EXC_CRASH",
            signal: "SIGABRT",
            terminationReason: "Test",
            virtualMemoryRegionInfo: nil
        )

        XCTAssertEqual(crash1, crash2)
        XCTAssertNotEqual(crash1, crash3)
    }

    // MARK: - Hashable Tests

    func testDiagnosticSummaryHashable() {
        var summary1 = DiagnosticSummary(timeRange: "Test Range")
        summary1.crashCount = 2

        var summary2 = DiagnosticSummary(timeRange: "Test Range")
        summary2.crashCount = 2

        var set = Set<DiagnosticSummary>()
        set.insert(summary1)
        set.insert(summary2)

        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Description Tests

    func testDescription() {
        var summary = DiagnosticSummary(timeRange: "Test Range")
        summary.crashCount = 2
        summary.hangCount = 5

        let description = summary.description
        XCTAssertTrue(description.contains("2"))
        XCTAssertTrue(description.contains("5"))
        XCTAssertTrue(description.contains("Test Range"))
    }
}
