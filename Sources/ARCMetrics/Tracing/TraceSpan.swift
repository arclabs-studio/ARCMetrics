//
//  TraceSpan.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// An in-flight span, returned by ``Tracing/begin(_:category:parent:attributes:)`` and handed back
/// to ``Tracing/end(_:outcome:attributes:)``.
///
/// Every tracer that sees a span receives this same token, so ``TeeTracer`` children agree on its
/// identity and timing.
public struct TraceSpan: Sendable {
    // MARK: - Properties

    /// Random, never `0` and never `UInt64.max`, so it is also a valid `OSSignpostID`.
    public let id: UInt64

    /// The literal the span opened with.
    public let name: StaticString

    /// The subsystem the span belongs to.
    public let category: SignpostCategory

    /// The ``id`` of the enclosing span, if any.
    public let parentID: UInt64?

    /// When the span began.
    public let startTime: Date

    // MARK: - Initialization

    /// Creates a span token. Prefer ``Tracing/begin(_:category:parent:attributes:)``, which also
    /// starts it.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - parentID: The enclosing span's ``id``.
    ///   - id: Leave at the default random value outside tests.
    ///   - startTime: When the span began.
    public init(name: StaticString,
                category: SignpostCategory,
                parentID: UInt64? = nil,
                id: UInt64 = .random(in: 1 ..< .max),
                startTime: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.parentID = parentID
        self.startTime = startTime
    }
}

// MARK: - Equatable

extension TraceSpan: Equatable {
    public static func == (lhs: TraceSpan, rhs: TraceSpan) -> Bool {
        lhs.id == rhs.id
            && "\(lhs.name)" == "\(rhs.name)"
            && lhs.category == rhs.category
            && lhs.parentID == rhs.parentID
            && lhs.startTime == rhs.startTime
    }
}
