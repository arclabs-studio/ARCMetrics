//
//  TracingTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import ARCMetrics
import ARCMetricsMocks
import Foundation
import Testing

@Suite("Tracing", .tags(.unit), .timeLimit(.minutes(1))) struct TracingTests {
    // MARK: - begin

    @Test("begin starts one span and returns that same span") func beginStartsAndReturns() {
        // Given
        let sut = RecordingTracer()

        // When
        let span = sut.begin("Load", category: .persistence)

        // Then
        #expect(sut.events == [.started(span, [:])])
        #expect("\(span.name)" == "Load")
        #expect(span.category == .persistence)
        #expect(span.parentID == nil)
    }

    @Test("begin passes attributes to start") func beginPassesAttributes() {
        // Given
        let sut = RecordingTracer()

        // When
        let span = sut.begin("Load", category: .network, attributes: ["retries": 2, "cached": false])

        // Then
        #expect(sut.events == [.started(span, ["retries": .int(2), "cached": .bool(false)])])
    }

    @Test("begin links the parent and mints a distinct id") func beginLinksParent() {
        // Given
        let sut = RecordingTracer()

        // When
        let parent = sut.begin("Parent", category: .launch)
        let child = sut.begin("Child", category: .launch, parent: parent)

        // Then
        #expect(child.parentID == parent.id)
        #expect(child.id != parent.id)
        #expect(parent.id != 0)
        #expect(child.id != 0)
    }

    // MARK: - trace (sync)

    @Test("trace brackets the operation with start and an ok end, returning its value") func traceHappyPath() throws {
        // Given
        let sut = RecordingTracer()

        // When
        let result = sut.trace("Work", category: .media, attributes: ["k": "v"]) { _ in 42 }

        // Then
        #expect(result == 42)
        #expect(sut.startedSpans.count == 1)
        #expect(sut.events.count == 2)
        let span = try #require(sut.startedSpans.first)
        #expect(sut.events == [.started(span, ["k": "v"]), .ended(span, .ok, [:])])
    }

    @Test("trace hands the operation the span it began") func traceHandsOperationTheSpan() {
        // Given
        let sut = RecordingTracer()
        let parent = TraceSpan(name: "Parent", category: .launch)

        // When
        let seen = sut.trace("Work", category: .launch, parent: parent) { $0 }

        // Then
        #expect(sut.startedSpans == [seen])
        #expect(sut.endedSpans == [seen])
        #expect(seen.parentID == parent.id)
    }

    @Test("trace has begun the span before the operation runs") func traceStartsBeforeOperation() {
        // Given
        let sut = RecordingTracer()

        // When
        let startedWhileRunning = sut.trace("Work", category: .launch) { _ in
            (sut.startedSpans.count, sut.endedSpans.count)
        }

        // Then
        #expect(startedWhileRunning.0 == 1)
        #expect(startedWhileRunning.1 == 0)
    }

    @Test("trace ends with the error type and rethrows the original error") func traceThrows() {
        // Given
        let sut = RecordingTracer()

        // When
        let thrown = #expect(throws: SecretError.self) {
            try sut.trace("Failing", category: .network) { _ in throw SecretError(secret: Self.secret) }
        }

        // Then
        #expect(thrown?.secret == Self.secret)
        guard let span = sut.startedSpans.first else {
            Issue.record("no span started")
            return
        }
        #expect(sut.events.last == .ended(span, .error(type: "SecretError"), [:]))
        #expect(sut.endedSpans.count == 1)
    }

    @Test("trace never records the error's message") func traceDoesNotLeakMessage() {
        // Given
        let sut = RecordingTracer()

        // When
        _ = try? sut.trace("Failing", category: .network) { _ -> Int in throw SecretError(secret: Self.secret) }

        // Then
        #expect(!String(describing: sut.events).contains(Self.secret))
    }

    // MARK: - trace (async)

    @Test("async trace brackets the operation and returns its value") func asyncTraceHappyPath() async throws {
        // Given
        let sut = RecordingTracer()

        // When
        let result = try await sut.trace("Work", category: .intelligence, attributes: ["n": 1]) { _ in
            try await Task.sleep(for: .milliseconds(1))
            return "done"
        }

        // Then
        #expect(result == "done")
        let span = try #require(sut.startedSpans.first)
        #expect(sut.events == [.started(span, ["n": .int(1)]), .ended(span, .ok, [:])])
    }

    @Test("async trace hands the operation the span it began") func asyncTraceHandsSpan() async {
        // Given
        let sut = RecordingTracer()
        let parent = TraceSpan(name: "Parent", category: .launch)

        // When
        let seen = await sut.trace("Work", category: .launch, parent: parent) { span async in span }

        // Then
        #expect(sut.startedSpans == [seen])
        #expect(seen.parentID == parent.id)
    }

    @Test("async trace ends with the error type, rethrows, and never records the message") func asyncTraceThrows() async {
        // Given
        let sut = RecordingTracer()

        // When
        let thrown = await #expect(throws: SecretError.self) {
            try await sut.trace("Failing", category: .network) { _ in
                try await Task.sleep(for: .milliseconds(1))
                throw SecretError(secret: Self.secret)
            }
        }

        // Then
        #expect(thrown?.secret == Self.secret)
        #expect(sut.endedSpans.count == 1)
        guard let span = sut.startedSpans.first else {
            Issue.record("no span started")
            return
        }
        #expect(sut.events.last == .ended(span, .error(type: "SecretError"), [:]))
        #expect(!String(describing: sut.events).contains(Self.secret))
    }

    @Test("async trace ends with CancellationError when the task is cancelled") func asyncTraceCancellation() async {
        // Given
        let sut = RecordingTracer()

        // When — cancel while the operation is suspended
        let task = Task {
            try await sut.trace("Cancelled", category: .network) { _ in
                try await Task.sleep(for: .seconds(10))
            }
        }
        await waitUntil { sut.startedSpans.count == 1 }
        task.cancel()
        let result = await task.result

        // Then
        #expect(throws: CancellationError.self) { try result.get() }
        guard let span = sut.startedSpans.first else {
            Issue.record("no span started")
            return
        }
        #expect(sut.events.last == .ended(span, .error(type: "CancellationError"), [:]))
    }

    // MARK: - NoOpTracer

    @Test("NoOpTracer runs sync and async operations and returns their values") func noOpRunsOperations() async {
        // Given
        let sut = NoOpTracer()
        var ran = 0

        // When
        let sync = sut.trace("Sync", category: .launch) { _ in
            ran += 1
            return 1
        }
        let asyncResult = await sut.trace("Async", category: .launch) { _ in
            await Task.yield()
            return 2
        }

        // Then — disabling tracing must never change behaviour
        #expect(sync == 1)
        #expect(asyncResult == 2)
        #expect(ran == 1)
    }

    @Test("A NoOpTracer beside a recording tracer in a tee changes nothing it records") func noOpIsInert() {
        // Given
        let recorder = RecordingTracer()
        let sut = TeeTracer([NoOpTracer(), recorder, NoOpTracer()])

        // When
        let span = sut.begin("Work", category: .launch, attributes: ["a": 1])
        sut.event("Milestone", category: .launch, attributes: ["b": true])
        sut.end(span, outcome: .ok, attributes: [:])

        // Then
        #expect(recorder.events == [.started(span, ["a": 1]),
                                    .event(name: "Milestone", category: "Launch", ["b": true]),
                                    .ended(span, .ok, [:])])
    }

    // MARK: - RecordingTracer

    @Test("RecordingTracer accessors filter and preserve order") func recordingTracerAccessors() {
        // Given
        let sut = RecordingTracer()
        let first = TraceSpan(name: "A", category: .launch)
        let second = TraceSpan(name: "B", category: .media)

        // When
        sut.start(first, attributes: ["x": 1])
        sut.start(second, attributes: [:])
        sut.event("Tick", category: .network, attributes: ["y": true])
        sut.end(second, outcome: .error(type: "Boom"), attributes: ["z": 1.5])
        sut.end(first, outcome: .ok, attributes: [:])

        // Then
        #expect(sut.startedSpans == [first, second])
        #expect(sut.endedSpans == [second, first])
        #expect(sut.events == [.started(first, ["x": .int(1)]),
                               .started(second, [:]),
                               .event(name: "Tick", category: "Network", ["y": .bool(true)]),
                               .ended(second, .error(type: "Boom"), ["z": .double(1.5)]),
                               .ended(first, .ok, [:])])
    }

    @Test("RecordingTracer records safely under concurrent use") func recordingTracerConcurrent() async {
        // Given
        let sut = RecordingTracer()

        // When
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 50 {
                group.addTask { _ = sut.trace("Work", category: .launch) { _ in 1 } }
            }
        }

        // Then
        #expect(sut.startedSpans.count == 50)
        #expect(sut.endedSpans.count == 50)
        #expect(Set(sut.startedSpans.map(\.id)).count == 50)
    }

    // MARK: - Fixtures

    private static let secret = "s3cr3t-token-9f8e7d"
}

// MARK: - Isolation

/// Proof that async `trace` runs the operation on the caller's isolation.
/// Mutating isolated state from a non-`Sendable` closure only compiles when
/// `isolation: #isolation` is threaded through.
@Suite("trace isolation", .tags(.unit), .timeLimit(.minutes(1))) struct TraceIsolationTests {
    private final class NonSendableBox {
        var value = 0
    }

    private actor Counter {
        private(set) var count = 0
        private(set) var wasIsolated = false

        func run(_ tracer: RecordingTracer) async {
            await tracer.trace("Isolated", category: .persistence) { _ in
                await Task.yield()
                count += 1
                self.assertIsolated()
                wasIsolated = true
            }
        }
    }

    @MainActor @Test("The operation runs on the main actor when called from it") func mainActorIsolation() async {
        // Given
        let sut = RecordingTracer()
        var counter = 0

        // When
        await sut.trace("Main", category: .launch) { _ in
            await Task.yield()
            MainActor.assertIsolated()
            counter += 1
        }

        // Then
        #expect(counter == 1)
        #expect(sut.endedSpans.count == 1)
    }

    @MainActor @Test("A non-Sendable value is returned through sending") func nonSendableResult() async throws {
        // Given
        let sut = RecordingTracer()

        // When
        let box = try await sut.trace("Box", category: .launch) { _ in
            let box = NonSendableBox()
            try await Task.sleep(for: .milliseconds(1))
            box.value = 9
            return box
        }

        // Then
        #expect(box.value == 9)
        #expect(sut.endedSpans.count == 1)
    }

    @Test("The operation mutates actor state synchronously from an isolated method") func customActorIsolation() async {
        // Given
        let sut = RecordingTracer()
        let counter = Counter()

        // When
        await counter.run(sut)

        // Then
        #expect(await counter.count == 1)
        #expect(await counter.wasIsolated)
        #expect(sut.endedSpans.count == 1)
    }
}

// MARK: - Test Doubles

private struct SecretError: Error, CustomStringConvertible, LocalizedError {
    let secret: String

    var description: String {
        "failed with \(secret)"
    }

    var errorDescription: String? {
        "failed with \(secret)"
    }
}
