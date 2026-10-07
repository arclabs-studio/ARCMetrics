//
//  SummaryCacheTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

import Foundation
import Testing
@testable import ARCMetrics

/// `SummaryCache` is what stops the `MXMetricManager` backend from
/// re-processing the same payload: MetricKit hands the same reporting window
/// back through both `didReceive` and `pastPayloads`.
///
/// Restores the coverage v1's `MetricKitProviderStateTests` had before the
/// caching moved into a backend that cannot be built on macOS.
@Suite("SummaryCache", .tags(.unit)) struct SummaryCacheTests {
    @Test("The same interval is computed once and then served from the cache") func sameIntervalComputesOnce() {
        // Given
        let sut = SummaryCache<String>()
        var computeCount = 0

        // When
        let first = sut.summary(for: .fixture()) {
            computeCount += 1
            return "first"
        }
        let second = sut.summary(for: .fixture()) {
            computeCount += 1
            return "second"
        }

        // Then
        #expect(first == "first")
        #expect(second == "first")
        #expect(computeCount == 1)
    }

    @Test("Distinct intervals are cached separately, never conflated") func distinctIntervalsAreNotConflated() {
        // Given
        let sut = SummaryCache<String>()
        let dayOne = DateInterval.fixture(startingAt: 1_700_000_000)
        let dayTwo = DateInterval.fixture(startingAt: 1_700_086_400)

        // When
        let first = sut.summary(for: dayOne) { "day one" }
        let second = sut.summary(for: dayTwo) { "day two" }

        // Then
        #expect(first == "day one")
        #expect(second == "day two")
        #expect(sut.summary(for: dayOne) { "recomputed" } == "day one")
    }
}
