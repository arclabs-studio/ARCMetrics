//
//  RecordingSignpostTracer.swift
//  ARCMetricsMocks
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import ARCMetrics
import Foundation
import struct os.OSAllocatedUnfairLock

/// A ``SignpostTracing`` double that records every call instead of emitting.
///
/// Use it to assert that instrumented code opens and closes its spans,
/// including when it throws:
///
/// ```swift
/// let tracer = RecordingSignpostTracer()
/// let sut = Repository(tracer: tracer)
///
/// _ = try? await sut.fetchAll()
///
/// #expect(tracer.beginCount == tracer.endCount)
/// ```
///
/// Checked `Sendable`: all mutable state lives behind a lock.
public final class RecordingSignpostTracer: SignpostTracing {
    // MARK: - Nested Types

    /// One recorded call.
    public enum Event: Sendable, Equatable {
        case emitted(name: String, category: String)
        case began(name: String, category: String, rawID: UInt64)
        case ended(name: String, category: String, rawID: UInt64)
    }

    private struct State {
        var events: [Event] = []
        var nextID: UInt64 = 1
    }

    // MARK: - Properties

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Every call, in order.
    public var events: [Event] {
        state.withLock { $0.events }
    }

    /// Number of intervals opened.
    public var beginCount: Int {
        events.count { event in
            if case .began = event {
                true
            } else {
                false
            }
        }
    }

    /// Number of intervals closed.
    public var endCount: Int {
        events.count { event in
            if case .ended = event {
                true
            } else {
                false
            }
        }
    }

    /// Raw IDs of every interval opened, in order.
    public var openedIDs: [UInt64] {
        events.compactMap { event in
            if case let .began(_, _, id) = event {
                id
            } else {
                nil
            }
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - SignpostTracing

    public func emit(_ name: StaticString, category: SignpostCategory) {
        state.withLock {
            $0.events.append(.emitted(name: "\(name)", category: category.rawValue))
        }
    }

    public func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval {
        let id = state.withLock { state -> UInt64 in
            let id = state.nextID
            state.nextID += 1
            state.events.append(.began(name: "\(name)", category: category.rawValue, rawID: id))
            return id
        }
        return SignpostInterval(name: name, category: category, rawID: id, isActive: true)
    }

    public func end(_ interval: SignpostInterval) {
        state.withLock {
            $0.events.append(.ended(name: "\(interval.name)",
                                    category: interval.category.rawValue,
                                    rawID: interval.rawID))
        }
    }
}
