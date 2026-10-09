//
//  TeeTracer.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// Forwards every call to each of its tracers, in order, with the same span token.
///
/// ```swift
/// let tracer = TeeTracer([MetricKitSignpostTracer(), otelTracer])
/// ```
public struct TeeTracer: Tracing {
    // MARK: - Properties

    private let tracers: [any Tracing]

    // MARK: - Initialization

    /// Creates a tracer that forwards to `tracers`.
    ///
    /// - Parameter tracers: The tracers to forward to, called in this order.
    public init(_ tracers: [any Tracing]) {
        self.tracers = tracers
    }

    // MARK: - Tracing

    public func start(_ span: TraceSpan, attributes: TraceAttributes) {
        for tracer in tracers {
            tracer.start(span, attributes: attributes)
        }
    }

    public func end(_ span: TraceSpan, outcome: TraceOutcome, attributes: TraceAttributes) {
        for tracer in tracers {
            tracer.end(span, outcome: outcome, attributes: attributes)
        }
    }

    public func event(_ name: StaticString, category: SignpostCategory, attributes: TraceAttributes) {
        for tracer in tracers {
            tracer.event(name, category: category, attributes: attributes)
        }
    }
}
