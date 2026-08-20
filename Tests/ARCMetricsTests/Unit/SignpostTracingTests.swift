//
//  SignpostTracingTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation
import Testing
@testable import ARCMetrics

@Suite("Signpost tracing", .tags(.unit)) struct SignpostTracingTests {
    // MARK: - Scoped Measurement

    @Test("measure opens exactly one interval and closes it") func measurePairsOnce() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        let result = sut.measure("Work", category: .persistence) { 42 }

        // Then
        #expect(result == 42)
        #expect(sut.beginCount == 1)
        #expect(sut.endCount == 1)
    }

    @Test("measure closes the interval before returning") func measureEndsBeforeReturning() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        sut.measure("Work", category: .launch) {}

        // Then — begin then end, in that order
        #expect(sut.events == [.began(name: "Work", category: "Launch", rawID: 1),
                               .ended(name: "Work", category: "Launch", rawID: 1)])
    }

    @Test("measure closes the interval when the operation throws") func measureEndsOnThrow() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        #expect(throws: SampleError.self) {
            try sut.measure("Failing", category: .network) { throw SampleError.boom }
        }

        // Then — a leaked begin would corrupt every later aggregate for this name
        #expect(sut.beginCount == 1)
        #expect(sut.endCount == 1)
    }

    @Test("async measure pairs begin and end") func asyncMeasurePairs() async throws {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        let result = try await sut.measure("AsyncWork", category: .intelligence) {
            try await Task.sleep(for: .milliseconds(5))
            return "done"
        }

        // Then
        #expect(result == "done")
        #expect(sut.beginCount == 1)
        #expect(sut.endCount == 1)
    }

    @Test("async measure closes the interval when the operation throws") func asyncMeasureEndsOnThrow() async {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        await #expect(throws: SampleError.self) {
            try await sut.measure("AsyncFailing", category: .network) {
                try await Task.sleep(for: .milliseconds(1))
                throw SampleError.boom
            }
        }

        // Then
        #expect(sut.endCount == 1)
    }

    @Test("async measure closes the interval on cancellation") func asyncMeasureEndsOnCancellation() async {
        // Given
        let sut = RecordingSignpostTracer()

        // When — cancel while the measured operation is suspended
        let task = Task {
            try await sut.measure("Cancelled", category: .network) {
                try await Task.sleep(for: .seconds(10))
            }
        }
        while sut.beginCount == 0 {
            await Task.yield()
        }
        task.cancel()
        _ = await task.result

        // Then
        #expect(sut.beginCount == 1)
        #expect(sut.endCount == 1)
    }

    @Test("Concurrent same-name intervals get distinct IDs") func concurrentIntervalsAreDistinct() async {
        // Given — the reason `begin` never mints `.exclusive`: overlapping
        // same-name spans are normal, and `.exclusive` would mispair them.
        let sut = RecordingSignpostTracer()

        // When
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 8 {
                group.addTask {
                    try? await sut.measure("Overlapping", category: .persistence) {
                        try await Task.sleep(for: .milliseconds(5))
                    }
                }
            }
        }

        // Then
        #expect(sut.beginCount == 8)
        #expect(sut.endCount == 8)
        #expect(Set(sut.openedIDs).count == 8)
    }

    // MARK: - Manual Intervals

    @Test("emit records a point-in-time event with no interval") func emitRecordsEvent() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        sut.emit("Milestone", category: .launch)

        // Then
        #expect(sut.events == [.emitted(name: "Milestone", category: "Launch")])
        #expect(sut.beginCount == 0)
    }

    @Test("A manual begin/end pair carries the same ID") func manualPairSharesID() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        let interval = sut.begin("Manual", category: .media)
        sut.end(interval)

        // Then
        #expect(sut.openedIDs.count == 1)
        #expect(sut.events.last == .ended(name: "Manual", category: "Media", rawID: interval.rawID))
    }

    // MARK: - No-Op Tracer

    @Test("NoOpSignpostTracer returns inactive tokens") func noOpReturnsInactive() {
        // Given
        let sut = NoOpSignpostTracer()

        // When
        let interval = sut.begin("Ignored", category: .launch)

        // Then
        #expect(!interval.isActive)
        #expect(interval.rawID == 0)
    }

    @Test("NoOpSignpostTracer still runs and returns the measured operation") func noOpRunsOperation() {
        // Given
        let sut = NoOpSignpostTracer()

        // When
        let result = sut.measure("Ignored", category: .launch) { "value" }

        // Then — disabling tracing must never change behaviour
        #expect(result == "value")
    }

    // MARK: - Disabled Tracer

    @Test("A disabled MetricKitSignpostTracer returns inactive tokens") func disabledTracerIsInactive() {
        // Given
        let sut = MetricKitSignpostTracer(isEnabled: false)

        // When
        let interval = sut.begin("Disabled", category: .launch)

        // Then
        #expect(!interval.isActive)
    }

    @Test("A disabled tracer still runs the measured operation") func disabledTracerRunsOperation() {
        // Given
        let sut = MetricKitSignpostTracer(isEnabled: false)

        // When
        let result = sut.measure("Disabled", category: .launch) { 7 }

        // Then
        #expect(result == 7)
    }

    @Test("An enabled tracer emits without trapping") func enabledTracerEmits() {
        // Given — exercises real OSLog handle creation and emission
        let sut = MetricKitSignpostTracer()

        // When
        let result = sut.measure("RealEmission", category: .persistence) { 1 }
        sut.emit("RealEvent", category: .persistence)

        // Then
        #expect(result == 1)
    }
}

/// Compile-level proof of the `measure` isolation contract.
///
/// If `isolation: #isolation` were not threaded correctly, wrapping `@MainActor`
/// work would demand `T: Sendable` and insert a suspension — on the launch path,
/// the one place that is least affordable. `NonSendableBox` is deliberately not
/// `Sendable`: this suite failing to *compile* is the assertion.
@Suite("measure isolation", .tags(.unit))
@MainActor
struct SignpostMeasureIsolationTests {
    private final class NonSendableBox {
        var value = 0
    }

    @Test("Async measure returns a non-Sendable value from a MainActor context") func returnsNonSendable() async throws {
        // Given
        let sut = RecordingSignpostTracer()

        // When — the operation genuinely suspends, so the non-Sendable result
        // crosses a suspension point. `sending T` is what permits that.
        let box = try await sut.measure("MainActorWork", category: .launch) {
            let box = NonSendableBox()
            try await Task.sleep(for: .milliseconds(1))
            box.value = 9
            return box
        }

        // Then
        #expect(box.value == 9)
        #expect(sut.beginCount == 1)
        #expect(sut.endCount == 1)
    }

    @Test("Sync measure returns a non-Sendable value from a MainActor context") func syncReturnsNonSendable() {
        // Given
        let sut = RecordingSignpostTracer()

        // When
        let box = sut.measure("MainActorSync", category: .launch) { NonSendableBox() }

        // Then
        #expect(box.value == 0)
        #expect(sut.endCount == 1)
    }
}

// MARK: - Categories

@Suite("SignpostCategory", .tags(.unit)) struct SignpostCategoryTests {
    @Test("Standard categories carry their display names") func standardCategoryNames() {
        #expect(SignpostCategory.launch.rawValue == "Launch")
        #expect(SignpostCategory.persistence.rawValue == "Persistence")
        #expect(SignpostCategory.network.rawValue == "Network")
        #expect(SignpostCategory.media.rawValue == "Media")
        #expect(SignpostCategory.intelligence.rawValue == "Intelligence")
    }

    @Test("A category can be written as a string literal") func expressibleByStringLiteral() {
        // Given / When
        let custom: SignpostCategory = "Sync"

        // Then
        #expect(custom.rawValue == "Sync")
        #expect(custom == SignpostCategory(rawValue: "Sync"))
    }

    @Test("Categories with the same raw value hash alike") func hashesByRawValue() {
        // Given / When / Then
        #expect(Set([SignpostCategory.launch, "Launch"]).count == 1)
    }
}

// MARK: - Test Doubles

private enum SampleError: Error {
    case boom
}
