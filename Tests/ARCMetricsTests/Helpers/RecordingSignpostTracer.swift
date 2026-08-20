//
//  RecordingSignpostTracer.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation
@testable import ARCMetrics

/// Captures signpost activity so a test can assert on pairing and ordering.
///
/// Moves into the `ARCMetricsMocks` product in the next PR; consumers cannot
/// `@testable import` across a package boundary.
final class RecordingSignpostTracer: SignpostTracing, @unchecked Sendable {
    enum Event: Sendable, Equatable {
        case emitted(name: String, category: String)
        case began(name: String, category: String, rawID: UInt64)
        case ended(name: String, category: String, rawID: UInt64)
    }

    private let lock = NSLock()
    private var storage: [Event] = []
    private var nextID: UInt64 = 1

    var events: [Event] {
        lock.withLock { storage }
    }

    var beginCount: Int {
        events.filter {
            if case .began = $0 {
                true
            } else {
                false
            }
        }.count
    }

    var endCount: Int {
        events.filter {
            if case .ended = $0 {
                true
            } else {
                false
            }
        }.count
    }

    /// Raw IDs of every interval opened, in order.
    var openedIDs: [UInt64] {
        events.compactMap {
            if case let .began(_, _, id) = $0 {
                id
            } else {
                nil
            }
        }
    }

    func emit(_ name: StaticString, category: SignpostCategory) {
        lock.withLock {
            storage.append(.emitted(name: "\(name)", category: category.rawValue))
        }
    }

    func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval {
        let id = lock.withLock { () -> UInt64 in
            let id = nextID
            nextID += 1
            storage.append(.began(name: "\(name)", category: category.rawValue, rawID: id))
            return id
        }
        return SignpostInterval(name: name, category: category, rawID: id, isActive: true)
    }

    func end(_ interval: SignpostInterval) {
        lock.withLock {
            storage.append(.ended(name: "\(interval.name)",
                                  category: interval.category.rawValue,
                                  rawID: interval.rawID))
        }
    }
}
