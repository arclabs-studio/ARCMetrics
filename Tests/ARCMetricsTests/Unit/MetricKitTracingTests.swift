//
//  MetricKitTracingTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation
import os
import Testing
@testable import ARCMetrics

/// Signposts cannot be read back from a test process, so these tests observe what the tracer
/// emits through its `emissionObserver` seam.
///
/// `MetricKitSignpostTracer` conforms to both `SignpostTracing` and `Tracing`; each test pins the
/// protocol through an existential so `begin` resolves to the `Tracing` helper.
@Suite("MetricKitSignpostTracer as Tracing", .tags(.unit), .timeLimit(.minutes(1))) struct MetricKitTracingTests {
    /// Collects every emission the tracer reports.
    private final class EmissionLog: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: [SignpostEmission]())

        var emissions: [SignpostEmission] {
            storage.withLock { $0 }
        }

        func record(_ emission: SignpostEmission) {
            storage.withLock { $0.append(emission) }
        }
    }

    private func makeSUT(isEnabled: Bool = true) -> (sut: any Tracing, log: EmissionLog) {
        let log = EmissionLog()
        let sut = MetricKitSignpostTracer(isEnabled: isEnabled) { log.record($0) }
        return (sut, log)
    }

    // MARK: - Enabled

    @Test("A span's begin and end signposts both carry the span id as their signpost id")
    func spanIDBecomesSignpostID() {
        // Given
        let (sut, log) = makeSUT()

        // When
        let span = sut.begin("Fetch", category: .persistence, attributes: ["count": 3])
        sut.end(span, outcome: .error(type: "URLError"), attributes: ["late": true])

        // Then — attributes and outcome are dropped; only name, category and id reach the signpost
        #expect(log.emissions == [SignpostEmission(kind: .begin, name: "Fetch", category: .persistence, id: span.id),
                                  SignpostEmission(kind: .end, name: "Fetch", category: .persistence, id: span.id)])
    }

    @Test("Overlapping spans keep their own ids, so ends pair with the right begins") func overlappingSpansPair() {
        // Given
        let (sut, log) = makeSUT()

        // When
        let outer = sut.begin("Import", category: .persistence)
        let inner = sut.begin("Import", category: .persistence, parent: outer)
        sut.end(outer, outcome: .ok, attributes: [:])
        sut.end(inner, outcome: .ok, attributes: [:])

        // Then
        #expect(log.emissions.map(\.id) == [outer.id, inner.id, outer.id, inner.id])
        #expect(log.emissions.map(\.kind) == [.begin, .begin, .end, .end])
    }

    @Test("An event emits one event signpost with a valid id") func eventEmits() throws {
        // Given
        let (sut, log) = makeSUT()

        // When
        sut.event("Milestone", category: .launch, attributes: ["a": "b"])

        // Then
        let emission = try #require(log.emissions.first)
        #expect(log.emissions.count == 1)
        #expect(emission.kind == .event)
        #expect(emission.name == "Milestone")
        #expect(emission.category == .launch)
        #expect(emission.id != 0)
        #expect(emission.id != UInt64.max)
    }

    @Test("trace emits begin and end with the same id, also when the operation throws")
    func traceEmitsPairedSignposts() {
        // Given
        let (sut, log) = makeSUT()

        // When
        let value = sut.trace("Work", category: .network) { _ in 1 }
        #expect(throws: BoomError.self) {
            try sut.trace("Failing", category: .network) { _ in throw BoomError() }
        }

        // Then
        let emissions = log.emissions
        #expect(value == 1)
        #expect(emissions.map(\.kind) == [.begin, .end, .begin, .end])
        #expect(emissions.map(\.name) == ["Work", "Work", "Failing", "Failing"])
        #expect(emissions[0].id == emissions[1].id)
        #expect(emissions[2].id == emissions[3].id)
    }

    // MARK: - Disabled

    @Test("A disabled tracer emits nothing for begin, end, event or trace") func disabledEmitsNothing() async throws {
        // Given
        let (sut, log) = makeSUT(isEnabled: false)

        // When
        let span = sut.begin("Disabled", category: .launch)
        sut.end(span, outcome: .ok, attributes: [:])
        sut.event("Milestone", category: .launch, attributes: [:])
        let value = try await sut.trace("Async", category: .launch) { _ in
            try await Task.sleep(for: .milliseconds(1))
            return 8
        }

        // Then — tracing switched off never changes the traced work
        #expect(log.emissions.isEmpty)
        #expect(value == 8)
    }
}

private struct BoomError: Error {}
