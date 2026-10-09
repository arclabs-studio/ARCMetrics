//
//  NoOpTracer.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// Records nothing.
///
/// Use for tests that don't assert on tracing, and wherever tracing is switched off.
public struct NoOpTracer: Tracing {
    /// Creates a tracer that records nothing.
    public init() {}

    public func start(_: TraceSpan, attributes _: TraceAttributes) {}

    public func end(_: TraceSpan, outcome _: TraceOutcome, attributes _: TraceAttributes) {}

    public func event(_: StaticString, category _: SignpostCategory, attributes _: TraceAttributes) {}
}
