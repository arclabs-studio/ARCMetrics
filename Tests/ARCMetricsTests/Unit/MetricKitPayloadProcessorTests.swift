//
//  MetricKitPayloadProcessorTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import ARCLogger
import Foundation
import Testing
@testable import ARCMetrics

@Suite("MetricKitPayloadProcessor", .tags(.unit)) struct MetricKitPayloadProcessorTests {
    // MARK: - Histogram Arithmetic

    @Test("Weighted total of an empty histogram is zero") func totalOfEmptyHistogram() {
        // Given / When
        let total = MetricKitPayloadProcessor.weightedTotalSeconds([])

        // Then
        #expect(total == 0)
    }

    @Test("Weighted total sums each bucket's lower edge times its count") func totalWeightsLowerEdge() {
        // Given
        let buckets = [DurationBucket(startSeconds: 0.25, endSeconds: 0.5, count: 4),
                       DurationBucket(startSeconds: 1.0, endSeconds: 2.0, count: 2)]

        // When
        let total = MetricKitPayloadProcessor.weightedTotalSeconds(buckets)

        // Then — 0.25 * 4 + 1.0 * 2
        #expect(total == 3.0)
    }

    @Test("Weighted average divides by total sample count, not bucket count") func averageDividesBySamples() {
        // Given
        let buckets = [DurationBucket(startSeconds: 0.25, endSeconds: 0.5, count: 4),
                       DurationBucket(startSeconds: 1.0, endSeconds: 2.0, count: 2)]

        // When
        let average = MetricKitPayloadProcessor.weightedAverageSeconds(buckets)

        // Then — 3.0 seconds spread over 6 samples
        #expect(average == 0.5)
    }

    @Test("Weighted average of a histogram with only empty buckets is zero") func averageOfEmptyBuckets() {
        // Given
        let buckets = [DurationBucket(startSeconds: 0.25, endSeconds: 0.5, count: 0)]

        // When / Then — no division by zero
        #expect(MetricKitPayloadProcessor.weightedAverageSeconds(buckets) == 0)
    }

    // MARK: - Metric Payload

    @Test("An empty payload maps every non-optional metric to zero, never to nil") func emptyPayloadMapsToZero() {
        // Given
        let sut = makeSUT()

        // When — hitch ratios are excluded here: they are `Double?` and default
        // to `nil`, not `0`. See `hitchRatiosDefaultToNilNotZero` below.
        let summary = sut.processMetricPayload(StubMetricPayload())

        // Then
        #expect(summary.peakMemoryUsageMB == 0)
        #expect(summary.cumulativeCPUTimeSeconds == 0)
        #expect(summary.totalHangTimeSeconds == 0)
        #expect(summary.averageLaunchTimeSeconds == 0)
    }

    @Test("Scalar metrics are forwarded verbatim") func forwardsScalarMetrics() {
        // Given
        let sut = makeSUT()
        let payload = StubMetricPayload(peakMemoryMB: 180,
                                        averageSuspendedMemoryMB: 42,
                                        cumulativeCPUTimeSeconds: 120,
                                        cumulativeGPUTimeSeconds: 7,
                                        foregroundTimeSeconds: 600,
                                        backgroundTimeSeconds: 90,
                                        cellularDownloadMB: 1.5,
                                        cellularUploadMB: 0.5,
                                        wifiDownloadMB: 12,
                                        wifiUploadMB: 3,
                                        cumulativeDiskWritesMB: 8)

        // When
        let summary = sut.processMetricPayload(payload)

        // Then
        #expect(summary.peakMemoryUsageMB == 180)
        #expect(summary.averageMemoryUsageMB == 42)
        #expect(summary.cumulativeCPUTimeSeconds == 120)
        #expect(summary.cumulativeGPUTimeSeconds == 7)
        #expect(summary.foregroundTimeSeconds == 600)
        #expect(summary.backgroundTimeSeconds == 90)
        #expect(summary.cellularDownloadMB == 1.5)
        #expect(summary.cellularUploadMB == 0.5)
        #expect(summary.wifiDownloadMB == 12)
        #expect(summary.wifiUploadMB == 3)
        #expect(summary.cumulativeDiskWritesMB == 8)
    }

    /// v2 spec change (user-approved, not a test edited to pass): the ×100
    /// conversion below was a verified bug — real MetricKit reports hitch
    /// ratios already in "ms per s" (measured on device 2026-10-06), not a
    /// 0...1 fraction. Both hitch fields now pass through unconverted; this
    /// replaces the old "converted to a percentage" test.
    @Test("Hitch ratios pass through unconverted, in ms per second") func hitchRatiosPassThroughUnconverted() {
        // Given
        let sut = makeSUT()
        let payload = StubMetricPayload(scrollHitchTimeRatio: 5.0, hitchTimeRatio: 7.5)

        // When
        let summary = sut.processMetricPayload(payload)

        // Then
        #expect(summary.scrollHitchTimeRatio == 5.0)
        #expect(summary.hitchTimeRatio == 7.5)
    }

    @Test("A nil hitch ratio from the source decodes as nil, not zero") func hitchRatiosDefaultToNilNotZero() {
        // Given
        let sut = makeSUT()

        // When
        let summary = sut.processMetricPayload(StubMetricPayload())

        // Then
        #expect(summary.scrollHitchTimeRatio == nil)
        #expect(summary.hitchTimeRatio == nil)
    }

    @Test("Average CPU percentage divides CPU time by foreground time") func derivesCPUPercentage() {
        // Given
        let sut = makeSUT()
        let payload = StubMetricPayload(cumulativeCPUTimeSeconds: 30, foregroundTimeSeconds: 600)

        // When
        let summary = sut.processMetricPayload(payload)

        // Then
        #expect(summary.averageCPUPercentage == 5)
    }

    @Test("Average CPU percentage is zero when the app never ran in foreground") func cpuPercentageWithoutForeground() {
        // Given
        let sut = makeSUT()

        // When
        let summary = sut.processMetricPayload(StubMetricPayload(cumulativeCPUTimeSeconds: 30))

        // Then — guards the division rather than producing infinity
        #expect(summary.averageCPUPercentage == 0)
    }

    @Test("Hang and launch histograms are reduced to total and average") func reducesHistograms() {
        // Given
        let sut = makeSUT()
        let payload = StubMetricPayload(hangTimeBuckets: [DurationBucket(startSeconds: 0.5,
                                                                         endSeconds: 1.0,
                                                                         count: 3)],
                                        launchTimeBuckets: [DurationBucket(startSeconds: 0.4,
                                                                           endSeconds: 0.6,
                                                                           count: 1),
                                                            DurationBucket(startSeconds: 0.8,
                                                                           endSeconds: 1.0,
                                                                           count: 1)])

        // When
        let summary = sut.processMetricPayload(payload)

        // Then
        #expect(summary.totalHangTimeSeconds == 1.5)
        #expect(abs(summary.averageLaunchTimeSeconds - 0.6) < 0.000_001)
    }

    @Test("The payload interval is carried onto the summary") func carriesInterval() {
        // Given
        let sut = makeSUT()
        let interval = DateInterval.fixture()

        // When
        let summary = sut.processMetricPayload(StubMetricPayload(interval: interval))

        // Then
        #expect(summary.interval == interval)
        #expect(!summary.timeRange.isEmpty)
    }

    // MARK: - Diagnostic Payload

    @Test("A clean diagnostic payload still produces a summary") func cleanDiagnosticPayload() {
        // Given
        let sut = makeSUT()

        // When
        let summary = sut.processDiagnosticPayload(StubDiagnosticPayload())

        // Then — a zero-crash day is a data point, not an absence of one
        #expect(summary.crashCount == 0)
        #expect(summary.crashes.isEmpty)
        #expect(summary.hangCount == 0)
        #expect(summary.hangs.isEmpty)
    }

    @Test("Crash details are forwarded field by field") func forwardsCrashDetails() {
        // Given
        let sut = makeSUT()
        let crash = CrashDiagnosticSource.fixture(virtualMemoryRegionInfo: "VM region 0x0")
        let payload = StubDiagnosticPayload(crashes: [crash])

        // When
        let summary = sut.processDiagnosticPayload(payload)

        // Then
        #expect(summary.crashCount == 1)
        #expect(summary.crashes.first?.exceptionType == "EXC_BAD_ACCESS")
        #expect(summary.crashes.first?.signal == "SIGSEGV")
        #expect(summary.crashes.first?.terminationReason == "Namespace SIGNAL")
        #expect(summary.crashes.first?.virtualMemoryRegionInfo == "VM region 0x0")
    }

    @Test("Counts track their detail arrays") func countsMatchDetails() {
        // Given
        let sut = makeSUT()
        let payload = StubDiagnosticPayload(crashes: [.fixture(), .fixture()],
                                            hangDurationsSeconds: [0.4, 1.2, 3.0],
                                            diskWriteExceptionCount: 5,
                                            cpuExceptionCount: 2)

        // When
        let summary = sut.processDiagnosticPayload(payload)

        // Then
        #expect(summary.crashCount == 2)
        #expect(summary.hangCount == 3)
        #expect(summary.hangs.map(\.duration) == [0.4, 1.2, 3.0])
        #expect(summary.diskWriteExceptionCount == 5)
        #expect(summary.cpuExceptionCount == 2)
    }

    // MARK: - Log Severity

    @Test("A diagnostic payload with a crash logs exactly one error") func crashLogsOneError() {
        // Given
        let logger = RecordingLogger()
        let sut = makeSUT(logger: logger)

        // When
        _ = sut.processDiagnosticPayload(StubDiagnosticPayload(crashes: [.fixture()]))

        // Then
        #expect(logger.entries(at: .error).count == 1)
    }

    @Test("A diagnostic payload without crashes logs no error") func cleanPayloadLogsNoError() {
        // Given — zero crashes is the daily common case and must not page anyone
        let logger = RecordingLogger()
        let sut = makeSUT(logger: logger)

        // When
        _ = sut.processDiagnosticPayload(StubDiagnosticPayload(hangDurationsSeconds: [2.0]))

        // Then
        #expect(logger.entries(at: .error).isEmpty)
    }

    // MARK: - Factory

    private func makeSUT(logger: any Logger = SilentLogger()) -> MetricKitPayloadProcessor {
        MetricKitPayloadProcessor(logger: logger)
    }
}
