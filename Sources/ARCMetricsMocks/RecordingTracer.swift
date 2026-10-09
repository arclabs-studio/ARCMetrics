//
//  RecordingTracer.swift
//  ARCMetricsMocks
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import ARCMetrics
import Foundation
import struct os.OSAllocatedUnfairLock

/// A ``Tracing`` double that records every call instead of emitting.
///
/// ```swift
/// let tracer = RecordingTracer()
/// let sut = Repository(tracer: tracer)
///
/// _ = try? await sut.fetchAll()
///
/// #expect(tracer.startedSpans == tracer.endedSpans)
/// ```
///
/// Checked `Sendable`: all mutable state lives behind a lock.
public final class RecordingTracer: Tracing {
    // MARK: - Nested Types

    /// One recorded call.
    public enum Event: Sendable, Equatable {
        /// ``Tracing/start(_:attributes:)`` was called with this span and these attributes.
        case started(TraceSpan, TraceAttributes)

        /// ``Tracing/end(_:outcome:attributes:)`` was called with this span, outcome and attributes.
        case ended(TraceSpan, TraceOutcome, TraceAttributes)

        /// ``Tracing/event(_:category:attributes:)`` was called. `name` is the literal's text and
        /// `category` the category's `rawValue`, for example `"Network"`.
        case event(name: String, category: String, TraceAttributes)
    }

    // MARK: - Properties

    private let state = OSAllocatedUnfairLock(initialState: [Event]())

    /// Every call, in order.
    public var events: [Event] {
        state.withLock { $0 }
    }

    /// Every span started, in order.
    public var startedSpans: [TraceSpan] {
        events.compactMap { event in
            if case let .started(span, _) = event {
                span
            } else {
                nil
            }
        }
    }

    /// Every span ended, in order.
    public var endedSpans: [TraceSpan] {
        events.compactMap { event in
            if case let .ended(span, _, _) = event {
                span
            } else {
                nil
            }
        }
    }

    // MARK: - Initialization

    /// Creates a tracer with nothing recorded.
    public init() {}

    // MARK: - Tracing

    public func start(_ span: TraceSpan, attributes: TraceAttributes) {
        state.withLock { $0.append(.started(span, attributes)) }
    }

    public func end(_ span: TraceSpan, outcome: TraceOutcome, attributes: TraceAttributes) {
        state.withLock { $0.append(.ended(span, outcome, attributes)) }
    }

    public func event(_ name: StaticString, category: SignpostCategory, attributes: TraceAttributes) {
        state.withLock { $0.append(.event(name: "\(name)", category: category.rawValue, attributes)) }
    }
}
