//
//  MetricSummaryTests.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import XCTest
@testable import ARCMetrics

final class MetricSummaryTests: XCTestCase {
    // MARK: - Initialization Tests

    func testInitialization() {
        let summary = MetricSummary(timeRange: "Test Range")

        XCTAssertEqual(summary.timeRange, "Test Range")
        XCTAssertEqual(summary.peakMemoryUsageMB, 0)
        XCTAssertEqual(summary.averageMemoryUsageMB, 0)
        XCTAssertEqual(summary.cumulativeCPUTimeSeconds, 0)
        XCTAssertEqual(summary.totalHangTimeSeconds, 0)
        XCTAssertEqual(summary.foregroundTimeSeconds, 0)
        XCTAssertEqual(summary.backgroundTimeSeconds, 0)
        XCTAssertEqual(summary.averageLaunchTimeSeconds, 0)
        XCTAssertEqual(summary.cellularDownloadMB, 0)
        XCTAssertEqual(summary.cellularUploadMB, 0)
        XCTAssertEqual(summary.wifiDownloadMB, 0)
        XCTAssertEqual(summary.wifiUploadMB, 0)
        XCTAssertEqual(summary.cumulativeGPUTimeSeconds, 0)
        XCTAssertEqual(summary.cumulativeDiskWritesMB, 0)
        XCTAssertEqual(summary.scrollHitchTimeRatio, 0)
    }

    // MARK: - CPU Percentage Tests

    func testAverageCPUPercentageCalculation() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeCPUTimeSeconds = 50
        summary.foregroundTimeSeconds = 100

        XCTAssertEqual(summary.averageCPUPercentage, 50.0, accuracy: 0.01)
    }

    func testAverageCPUPercentageWithZeroForeground() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeCPUTimeSeconds = 50
        summary.foregroundTimeSeconds = 0

        XCTAssertEqual(summary.averageCPUPercentage, 0)
    }

    func testAverageCPUPercentageMultiThreaded() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeCPUTimeSeconds = 200
        summary.foregroundTimeSeconds = 100

        // Multi-threaded apps can exceed 100%
        XCTAssertEqual(summary.averageCPUPercentage, 200.0, accuracy: 0.01)
    }

    // MARK: - New Metrics Tests

    func testGPUMetrics() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeGPUTimeSeconds = 25.5

        XCTAssertEqual(summary.cumulativeGPUTimeSeconds, 25.5, accuracy: 0.01)
    }

    func testDiskWriteMetrics() {
        var summary = MetricSummary(timeRange: "Test")
        summary.cumulativeDiskWritesMB = 100.0

        XCTAssertEqual(summary.cumulativeDiskWritesMB, 100.0, accuracy: 0.01)
    }

    func testScrollHitchMetrics() {
        var summary = MetricSummary(timeRange: "Test")
        summary.scrollHitchTimeRatio = 2.5

        XCTAssertEqual(summary.scrollHitchTimeRatio, 2.5, accuracy: 0.01)
    }

    // MARK: - Codable Tests

    func testCodable() throws {
        var summary = MetricSummary(timeRange: "Test Range")
        summary.peakMemoryUsageMB = 150.5
        summary.cumulativeCPUTimeSeconds = 100
        summary.foregroundTimeSeconds = 200
        summary.cumulativeGPUTimeSeconds = 25.0
        summary.cumulativeDiskWritesMB = 50.0
        summary.scrollHitchTimeRatio = 1.5

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MetricSummary.self, from: data)

        XCTAssertEqual(decoded.timeRange, summary.timeRange)
        XCTAssertEqual(decoded.peakMemoryUsageMB, summary.peakMemoryUsageMB, accuracy: 0.01)
        XCTAssertEqual(decoded.cumulativeGPUTimeSeconds, summary.cumulativeGPUTimeSeconds, accuracy: 0.01)
        XCTAssertEqual(decoded.cumulativeDiskWritesMB, summary.cumulativeDiskWritesMB, accuracy: 0.01)
        XCTAssertEqual(decoded.scrollHitchTimeRatio, summary.scrollHitchTimeRatio, accuracy: 0.01)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        var summary1 = MetricSummary(timeRange: "Test Range")
        summary1.peakMemoryUsageMB = 150.5

        var summary2 = MetricSummary(timeRange: "Test Range")
        summary2.peakMemoryUsageMB = 150.5

        var summary3 = MetricSummary(timeRange: "Different Range")
        summary3.peakMemoryUsageMB = 150.5

        XCTAssertEqual(summary1, summary2)
        XCTAssertNotEqual(summary1, summary3)
    }

    // MARK: - Hashable Tests

    func testHashable() {
        var summary1 = MetricSummary(timeRange: "Test Range")
        summary1.peakMemoryUsageMB = 150.5

        var summary2 = MetricSummary(timeRange: "Test Range")
        summary2.peakMemoryUsageMB = 150.5

        var set = Set<MetricSummary>()
        set.insert(summary1)
        set.insert(summary2)

        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Description Tests

    func testDescription() {
        var summary = MetricSummary(timeRange: "Test Range")
        summary.peakMemoryUsageMB = 150.5

        let description = summary.description
        XCTAssertTrue(description.contains("150.5"))
        XCTAssertTrue(description.contains("Test Range"))
    }
}
