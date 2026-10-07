//
//  AsyncStreamTestSupport.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import Foundation

/// Consumes `sequence` until `count` elements have arrived, then stops
/// iterating.
///
/// Shared by every suite that asserts on `AsyncStream` fan-out
/// (`SummaryBroadcaster`, `MetricsCollector`) so each test states only how
/// many elements it expects, not how to drive the sequence.
func collectFirst<S: AsyncSequence>(_ sequence: S, count: Int) async rethrows -> [S.Element] {
    var results: [S.Element] = []
    for try await value in sequence {
        results.append(value)
        if results.count == count {
            break
        }
    }
    return results
}

/// Polls `condition` in small, bounded steps rather than sleeping for a fixed
/// duration.
///
/// Used only where production exposes no event to synchronize on directly
/// (e.g. a subscriber count dropping after cancellation). Bounded at ~20ms of
/// total sleeping so a genuine regression fails fast instead of hanging.
func waitUntil(attempts: Int = 20, _ condition: @Sendable () -> Bool) async {
    for _ in 0 ..< attempts {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
}
