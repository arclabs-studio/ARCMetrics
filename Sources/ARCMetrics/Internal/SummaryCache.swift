//
//  SummaryCache.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-07.
//

import Foundation
import struct os.OSAllocatedUnfairLock

/// Remembers one summary per reporting interval.
///
/// `MXMetricManager` hands the same window back through both `didReceive` and
/// `pastPayloads`; this keeps each one processed once. Platform-free so it is
/// testable on macOS, where the backend that uses it does not exist.
final class SummaryCache<Summary: Sendable>: Sendable {
    // MARK: - Properties

    private let summaries = OSAllocatedUnfairLock<[DateInterval: Summary]>(initialState: [:])

    // MARK: - Lookup

    /// Returns the summary cached for `interval`, computing and storing it on
    /// first use.
    ///
    /// `compute` runs outside the lock. Two concurrent misses for the same
    /// interval may both compute, but the first one stored wins, so every
    /// caller sees the same summary.
    func summary(for interval: DateInterval, orCompute compute: () -> Summary) -> Summary {
        if let cached = summaries.withLock({ $0[interval] }) {
            return cached
        }
        let computed = compute()
        return summaries.withLock { summaries in
            if let stored = summaries[interval] {
                return stored
            }
            summaries[interval] = computed
            return computed
        }
    }
}
