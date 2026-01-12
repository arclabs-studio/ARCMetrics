//
//  MetricKitProviderTests.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-08.
//

import XCTest
@testable import ARCMetrics

final class MetricKitProviderTests: XCTestCase {
    // MARK: - Singleton Tests

    func testSingleton() {
        let provider1 = MetricKitProvider.shared
        let provider2 = MetricKitProvider.shared

        XCTAssertTrue(provider1 === provider2, "Provider should be a singleton")
    }

    // MARK: - Collection Tests

    func testStartCollecting() {
        let provider = MetricKitProvider.shared

        XCTAssertNoThrow(provider.startCollecting())
    }

    func testStopCollecting() {
        let provider = MetricKitProvider.shared

        provider.startCollecting()
        XCTAssertNoThrow(provider.stopCollecting())
    }

    // MARK: - Callback Tests

    func testCallbacksAreOptional() {
        let provider = MetricKitProvider.shared

        XCTAssertNil(provider.onMetricPayloadsReceived)
        XCTAssertNil(provider.onDiagnosticPayloadsReceived)
    }

    func testMetricCallbackCanBeSet() {
        let provider = MetricKitProvider.shared

        provider.onMetricPayloadsReceived = { _ in }
        XCTAssertNotNil(provider.onMetricPayloadsReceived)

        // Clean up
        provider.onMetricPayloadsReceived = nil
    }

    func testDiagnosticCallbackCanBeSet() {
        let provider = MetricKitProvider.shared

        provider.onDiagnosticPayloadsReceived = { _ in }
        XCTAssertNotNil(provider.onDiagnosticPayloadsReceived)

        // Clean up
        provider.onDiagnosticPayloadsReceived = nil
    }

    // MARK: - Historical Data Tests

    func testPastMetricSummariesAccessible() {
        let provider = MetricKitProvider.shared

        let pastSummaries = provider.pastMetricSummaries
        XCTAssertNotNil(pastSummaries)
    }

    func testPastDiagnosticSummariesAccessible() {
        let provider = MetricKitProvider.shared

        let pastSummaries = provider.pastDiagnosticSummaries
        XCTAssertNotNil(pastSummaries)
    }

    // MARK: - Protocol Conformance Tests

    func testConformsToMetricsProviding() {
        let provider: MetricsProviding = MetricKitProvider.shared
        XCTAssertNotNil(provider)
    }

    func testConformsToSendable() {
        let provider = MetricKitProvider.shared

        // Should compile without warning - Sendable conformance
        Task {
            _ = provider.pastMetricSummaries
        }

        XCTAssertNotNil(provider)
    }
}
