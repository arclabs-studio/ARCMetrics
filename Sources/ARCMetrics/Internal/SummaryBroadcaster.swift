//
//  SummaryBroadcaster.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation
import struct os.OSAllocatedUnfairLock

/// Fans one source of values out to any number of `AsyncStream` subscribers.
///
/// `MetricManager` must not be iterated by more than one consumer: Apple
/// documents that two tasks iterating the same sequence each receive a
/// non-deterministic *subset* of reports. The package therefore reads each
/// sequence exactly once and multicasts from here, so the app's logger and a
/// later exporter can both see every summary.
///
/// There is no replay. A subscriber sees only what is yielded after it
/// subscribed; history comes from `pastMetricSummaries` /
/// `pastDiagnosticSummaries`.
///
/// `package` rather than `internal` so `ARCMetricsMocks` can reuse it.
package final class SummaryBroadcaster<Element: Sendable>: Sendable {
    // MARK: - Nested Types

    private struct State {
        var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]
        var isFinished = false
    }

    // MARK: - Properties

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Number of live subscribers.
    package var subscriberCount: Int {
        state.withLock { $0.continuations.count }
    }

    // MARK: - Initialization

    package init() {}

    // MARK: - Broadcasting

    /// Registers a new subscriber.
    ///
    /// The subscriber is removed when its stream terminates, whether the
    /// consumer stopped iterating, its task was cancelled, or ``finish()`` ran.
    /// A subscription made after ``finish()`` returns an already-finished stream.
    package func subscribe() -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        let id = UUID()
        let isFinished = state.withLock { state -> Bool in
            guard !state.isFinished else { return true }
            state.continuations[id] = continuation
            return false
        }
        guard !isFinished else {
            continuation.finish()
            return stream
        }
        continuation.onTermination = { [weak self] _ in
            self?.removeSubscriber(id)
        }
        return stream
    }

    /// Delivers `element` to every current subscriber.
    package func yield(_ element: Element) {
        // Copy out before yielding: never call out while holding the lock.
        let continuations = state.withLock { Array($0.continuations.values) }
        for continuation in continuations {
            continuation.yield(element)
        }
    }

    /// Ends every current stream and refuses new subscribers.
    package func finish() {
        let continuations = state.withLock { state -> [AsyncStream<Element>.Continuation] in
            state.isFinished = true
            let current = Array(state.continuations.values)
            state.continuations.removeAll()
            return current
        }
        for continuation in continuations {
            continuation.finish()
        }
    }
}

// MARK: - Private Helpers

extension SummaryBroadcaster {
    private func removeSubscriber(_ id: UUID) {
        state.withLock { _ = $0.continuations.removeValue(forKey: id) }
    }
}
