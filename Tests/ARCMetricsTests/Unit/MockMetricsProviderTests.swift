//
//  MockMetricsProviderTests.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import XCTest
@testable import ARCMetrics

final class MockMetricsProviderTests: XCTestCase {
    var mock: MockMetricsProvider!

    override func setUp() {
        super.setUp()
        mock = MockMetricsProvider()
    }

    override func tearDown() {
        mock = nil
        super.tearDown()
    }

    // MARK: - Collection State Tests

    func testStartCollecting() {
        XCTAssertFalse(mock.isCollecting)
        XCTAssertEqual(mock.startCollectingCallCount, 0)

        mock.startCollecting()

        XCTAssertTrue(mock.isCollecting)
        XCTAssertEqual(mock.startCollectingCallCount, 1)
    }

    func testStopCollecting() {
        mock.startCollecting()
        XCTAssertTrue(mock.isCollecting)

        mock.stopCollecting()

        XCTAssertFalse(mock.isCollecting)
        XCTAssertEqual(mock.stopCollectingCallCount, 1)
    }

    func testMultipleStartStopCalls() {
        mock.startCollecting()
        mock.startCollecting()
        mock.stopCollecting()

        XCTAssertEqual(mock.startCollectingCallCount, 2)
        XCTAssertEqual(mock.stopCollectingCallCount, 1)
    }

    // MARK: - Metric Simulation Tests

    func testSimulateMetricPayload() {
        let summary = MockMetricsProvider.sampleMetricSummary(timeRange: "Test Range")
        mock.simulateMetricPayload(summary)

        // Verify via pastMetricSummaries
        XCTAssertEqual(mock.pastMetricSummaries.count, 1)
        XCTAssertEqual(mock.pastMetricSummaries.first?.timeRange, "Test Range")
    }

    func testSimulateMultipleMetricPayloads() {
        let summaries = [
            MockMetricsProvider.sampleMetricSummary(timeRange: "Range 1"),
            MockMetricsProvider.sampleMetricSummary(timeRange: "Range 2")
        ]
        mock.simulateMetricPayload(summaries)

        XCTAssertEqual(mock.pastMetricSummaries.count, 2)
        XCTAssertEqual(mock.pastMetricSummaries[0].timeRange, "Range 1")
        XCTAssertEqual(mock.pastMetricSummaries[1].timeRange, "Range 2")
    }

    func testCallbackIsInvoked() {
        let expectation = expectation(description: "Callback invoked")

        mock.onMetricPayloadsReceived = { _ in
            expectation.fulfill()
        }

        mock.simulateMetricPayload(MockMetricsProvider.sampleMetricSummary())

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Diagnostic Simulation Tests

    func testSimulateDiagnosticPayload() {
        let summary = MockMetricsProvider.sampleDiagnosticSummary(crashCount: 2)
        mock.simulateDiagnosticPayload(summary)

        XCTAssertEqual(mock.pastDiagnosticSummaries.count, 1)
        XCTAssertEqual(mock.pastDiagnosticSummaries.first?.crashCount, 2)
    }

    func testDiagnosticCallbackIsInvoked() {
        let expectation = expectation(description: "Diagnostic callback invoked")

        mock.onDiagnosticPayloadsReceived = { _ in
            expectation.fulfill()
        }

        mock.simulateDiagnosticPayload(MockMetricsProvider.sampleDiagnosticSummary())

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Past Summaries Tests

    func testPastMetricSummaries() {
        XCTAssertTrue(mock.pastMetricSummaries.isEmpty)

        let summary = MockMetricsProvider.sampleMetricSummary()
        mock.simulateMetricPayload(summary)

        XCTAssertEqual(mock.pastMetricSummaries.count, 1)
    }

    func testPastDiagnosticSummaries() {
        XCTAssertTrue(mock.pastDiagnosticSummaries.isEmpty)

        let summary = MockMetricsProvider.sampleDiagnosticSummary()
        mock.simulateDiagnosticPayload(summary)

        XCTAssertEqual(mock.pastDiagnosticSummaries.count, 1)
    }

    // MARK: - Reset Tests

    func testReset() {
        mock.startCollecting()
        mock.simulateMetricPayload(MockMetricsProvider.sampleMetricSummary())
        mock.simulateDiagnosticPayload(MockMetricsProvider.sampleDiagnosticSummary())

        mock.reset()

        XCTAssertFalse(mock.isCollecting)
        XCTAssertEqual(mock.startCollectingCallCount, 0)
        XCTAssertEqual(mock.stopCollectingCallCount, 0)
        XCTAssertTrue(mock.pastMetricSummaries.isEmpty)
        XCTAssertTrue(mock.pastDiagnosticSummaries.isEmpty)
        XCTAssertNil(mock.onMetricPayloadsReceived)
        XCTAssertNil(mock.onDiagnosticPayloadsReceived)
    }

    // MARK: - Sample Data Generator Tests

    func testSampleMetricSummary() {
        let summary = MockMetricsProvider.sampleMetricSummary(
            timeRange: "Custom Range",
            peakMemory: 200.0,
            cpuTime: 100.0,
            foregroundTime: 200.0
        )

        XCTAssertEqual(summary.timeRange, "Custom Range")
        XCTAssertEqual(summary.peakMemoryUsageMB, 200.0, accuracy: 0.01)
        XCTAssertEqual(summary.cumulativeCPUTimeSeconds, 100.0, accuracy: 0.01)
        XCTAssertEqual(summary.foregroundTimeSeconds, 200.0, accuracy: 0.01)
    }

    func testSampleDiagnosticSummary() {
        let summary = MockMetricsProvider.sampleDiagnosticSummary(
            timeRange: "Custom Range",
            crashCount: 3,
            hangCount: 5
        )

        XCTAssertEqual(summary.timeRange, "Custom Range")
        XCTAssertEqual(summary.crashCount, 3)
        XCTAssertEqual(summary.hangCount, 5)
    }

    func testSampleCrashInfo() {
        let crashInfo = MockMetricsProvider.sampleCrashInfo(
            exceptionType: "EXC_CRASH",
            signal: "SIGABRT"
        )

        XCTAssertEqual(crashInfo.exceptionType, "EXC_CRASH")
        XCTAssertEqual(crashInfo.signal, "SIGABRT")
    }

    func testSampleHangInfo() {
        let hangInfo = MockMetricsProvider.sampleHangInfo(duration: 2.5)

        XCTAssertEqual(hangInfo.duration, 2.5, accuracy: 0.01)
    }

    // MARK: - Protocol Conformance Tests

    func testConformsToMetricsProviding() {
        let provider: MetricsProviding = mock
        XCTAssertNotNil(provider)
    }
}
