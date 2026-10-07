//
//  UnavailableMetricsBackendTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

import Foundation
import Testing
@testable import ARCMetrics

/// The macOS < 27 backend has nothing to read, so its whole contract is to
/// say so once instead of failing silently.
@Suite("UnavailableMetricsBackend", .tags(.unit)) struct UnavailableMetricsBackendTests {
    @Test("Starting logs a warning and delivers nothing") func startWarnsAndDeliversNothing() {
        // Given
        let logger = RecordingLogger()
        let sut = UnavailableMetricsBackend(logger: logger)
        let recorder = DeliveryRecorder()

        // When
        sut.start(delivering: recorder.delivery)

        // Then
        #expect(logger.entries(at: .warning).count == 1)
        #expect(recorder.metrics.isEmpty)
        #expect(recorder.diagnostics.isEmpty)
    }
}
