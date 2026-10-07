//
//  SummaryBroadcasterTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation
import Testing
@testable import ARCMetrics

/// `SummaryBroadcaster` is the multicast seam `MetricsCollector` is built on:
/// every call to `metricSummaries()` / `diagnosticSummaries()` must hand back
/// an independent subscriber, which is exactly what v1's single-slot
/// `onMetric` callback could not do (a second consumer silently stole the
/// first one's only delivery channel).
@Suite("SummaryBroadcaster", .tags(.unit), .timeLimit(.minutes(1))) struct SummaryBroadcasterTests {
    // MARK: - Fan-out

    @Test("Every current subscriber receives every yielded element, in order") func fanOutPreservesOrder() async {
        // Given
        let sut = SummaryBroadcaster<Int>()
        let first = sut.subscribe()
        let second = sut.subscribe()

        // When
        sut.yield(1)
        sut.yield(2)
        sut.finish()

        // Then
        async let firstReceived = collectFirst(first, count: 2)
        async let secondReceived = collectFirst(second, count: 2)
        #expect(await firstReceived == [1, 2])
        #expect(await secondReceived == [1, 2])
    }

    @Test("Subscribing twice gives two independent streams, not a shared one") func subscribersAreIndependent() {
        // Given / When
        // Both streams must stay alive: a dropped `AsyncStream` terminates and
        // is (correctly) unregistered, which `_ = subscribe()` would trigger.
        let sut = SummaryBroadcaster<Int>()
        let first = sut.subscribe()
        let second = sut.subscribe()

        // Then
        withExtendedLifetime((first, second)) {
            #expect(sut.subscriberCount == 2)
        }
    }

    // MARK: - Termination

    @Test("A cancelled subscriber is removed from the broadcaster") func cancelledSubscriberIsRemoved() async {
        // Given — a subscriber that disappears (view dismissed, task cancelled)
        // must not leak a slot the broadcaster keeps yielding into forever.
        let sut = SummaryBroadcaster<Int>()
        let stream = sut.subscribe()
        #expect(sut.subscriberCount == 1)

        let task = Task {
            for await _ in stream {}
        }

        // When
        task.cancel()

        // Then
        await waitUntil { sut.subscriberCount == 0 }
        #expect(sut.subscriberCount == 0)
    }

    @Test("finish ends every current stream") func finishEndsAllStreams() async {
        // Given
        let sut = SummaryBroadcaster<Int>()
        let first = sut.subscribe()
        let second = sut.subscribe()

        // When
        sut.finish()

        // Then — iteration must terminate (no hang) and yield nothing
        var firstReceived: [Int] = []
        for await value in first {
            firstReceived.append(value)
        }
        var secondReceived: [Int] = []
        for await value in second {
            secondReceived.append(value)
        }
        #expect(firstReceived.isEmpty)
        #expect(secondReceived.isEmpty)
    }

    // MARK: - No Replay

    @Test("A late subscriber receives nothing yielded before it subscribed") func lateSubscriberGetsNoReplay() async {
        // Given — the early subscriber must have actually observed the first
        // value before the late one joins, otherwise this proves nothing about
        // replay.
        let sut = SummaryBroadcaster<Int>()
        let early = sut.subscribe()
        await confirmation("the early subscriber observes the first value") { confirmed in
            let task = Task {
                for await value in early where value == 1 {
                    confirmed()
                    break
                }
            }
            sut.yield(1)
            _ = await task.value
        }

        // When
        let late = sut.subscribe()
        sut.yield(2)
        sut.finish()

        // Then
        var lateReceived: [Int] = []
        for await value in late {
            lateReceived.append(value)
        }
        #expect(lateReceived == [2])
    }
}
