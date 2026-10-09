//
//  TeeTracerTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import ARCMetrics
import ARCMetricsMocks
import Foundation
import os
import Testing

@Suite("TeeTracer", .tags(.unit), .timeLimit(.minutes(1))) struct TeeTracerTests {
    private struct Fixture {
        let sut: TeeTracer
        let first: RecordingTracer
        let second: RecordingTracer
    }

    private func makeSUT() -> Fixture {
        let first = RecordingTracer()
        let second = RecordingTracer()
        return Fixture(sut: TeeTracer([first, second]), first: first, second: second)
    }

    @Test("start hands the identical token to every tracer") func startForwards() {
        // Given
        let fixture = makeSUT()
        let sut = fixture.sut
        let first = fixture.first
        let second = fixture.second
        let span = TraceSpan(name: "Work", category: .network, parentID: 5, id: 77,
                             startTime: Date(timeIntervalSince1970: 123))

        // When
        sut.start(span, attributes: ["a": "b"])

        // Then
        let expected: [RecordingTracer.Event] = [.started(span, ["a": "b"])]
        #expect(first.events == expected)
        #expect(second.events == expected)
    }

    @Test("end hands the identical token, outcome and attributes to every tracer") func endForwards() {
        // Given
        let fixture = makeSUT()
        let sut = fixture.sut
        let first = fixture.first
        let second = fixture.second
        let span = TraceSpan(name: "Work", category: .media, parentID: 5, id: 78,
                             startTime: Date(timeIntervalSince1970: 456))

        // When
        sut.end(span, outcome: .error(type: "Boom"), attributes: ["n": 3])

        // Then
        let expected: [RecordingTracer.Event] = [.ended(span, .error(type: "Boom"), ["n": .int(3)])]
        #expect(first.events == expected)
        #expect(second.events == expected)
    }

    @Test("event forwards name, category and attributes to every tracer") func eventForwards() {
        // Given
        let fixture = makeSUT()
        let sut = fixture.sut
        let first = fixture.first
        let second = fixture.second

        // When
        sut.event("Milestone", category: .launch, attributes: ["ok": true])

        // Then
        let expected: [RecordingTracer.Event] = [.event(name: "Milestone", category: "Launch", ["ok": .bool(true)])]
        #expect(first.events == expected)
        #expect(second.events == expected)
    }

    @Test("A traced span reaches both tracers with the same token start to end") func traceSharesToken() throws {
        // Given
        let fixture = makeSUT()
        let sut = fixture.sut
        let first = fixture.first
        let second = fixture.second

        // When
        _ = sut.trace("Work", category: .persistence, attributes: ["k": 1]) { _ in 0 }

        // Then
        let span = try #require(first.startedSpans.first)
        #expect(first.events == [.started(span, ["k": .int(1)]), .ended(span, .ok, [:])])
        #expect(second.events == first.events)
    }

    @Test("Calls reach tracers in the order given") func ordering() {
        // Given — a shared log lets us see cross-tracer ordering
        let log = OrderLog()
        let sut = TeeTracer([OrderTracer(label: "first", log: log), OrderTracer(label: "second", log: log)])

        // When
        sut.event("E", category: .launch, attributes: [:])

        // Then
        #expect(log.entries == ["first", "second"])
    }

    @Test("An empty tee is a harmless no-op") func emptyTee() {
        // Given
        let sut = TeeTracer([])

        // When
        let result = sut.trace("Work", category: .launch) { _ in 5 }

        // Then
        #expect(result == 5)
    }
}

// MARK: - Test Doubles

private final class OrderLog: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [String]())

    var entries: [String] {
        storage.withLock { $0 }
    }

    func append(_ entry: String) {
        storage.withLock { $0.append(entry) }
    }
}

private struct OrderTracer: Tracing {
    let label: String
    let log: OrderLog

    func start(_: TraceSpan, attributes _: TraceAttributes) {
        log.append(label)
    }

    func end(_: TraceSpan, outcome _: TraceOutcome, attributes _: TraceAttributes) {
        log.append(label)
    }

    func event(_: StaticString, category _: SignpostCategory, attributes _: TraceAttributes) {
        log.append(label)
    }
}
