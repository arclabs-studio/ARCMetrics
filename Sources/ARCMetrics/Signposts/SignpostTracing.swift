//
//  SignpostTracing.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation

/// Emits signposts for operations you want to measure.
///
/// MetricKit aggregates signposts your app emits and reports them alongside its
/// built-in metrics, which is the only way to see *your own code* in Xcode
/// Organizer. The same emissions show up live in Instruments' Points of
/// Interest track.
///
/// ## What a span can carry
///
/// **Name, category, duration, and a system-supplied power/performance snapshot
/// — nothing else.** The underlying `mxSignpost` format and argument parameters
/// are reserved for internal system use, and `name` is a `StaticString`, so span
/// names are compile-time literals.
///
/// Anything with a payload — a restaurant count, a provider identifier, a
/// geocoder tier — is a normal analytics event, not a span.
///
/// ## Example
///
/// ```swift
/// let tracer = MetricKitSignpostTracer()
///
/// let restaurants = try await tracer.measure("FetchAll", category: .persistence) {
///     try await repository.fetchAll()
/// }
/// ```
///
/// ## Topics
///
/// ### Measuring
/// - ``measure(_:category:operation:)-6xj3s``
/// - ``measure(_:category:isolation:operation:)``
///
/// ### Manual Intervals
/// - ``begin(_:category:)``
/// - ``end(_:)``
///
/// ### Instantaneous Events
/// - ``emit(_:category:)``
public protocol SignpostTracing: Sendable {
    /// Emits a single point-in-time event, with no duration.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the event.
    ///   - category: Subsystem the event belongs to.
    func emit(_ name: StaticString, category: SignpostCategory)

    /// Opens an interval.
    ///
    /// Prefer ``measure(_:category:operation:)-6xj3s``, which cannot leak an
    /// unclosed interval. Use this directly only when begin and end genuinely
    /// cannot share a scope.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    /// - Returns: A token to hand to ``end(_:)``.
    func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval

    /// Closes an interval opened by ``begin(_:category:)``.
    ///
    /// - Parameter interval: The token `begin` returned. Ending the same token
    ///   twice emits a second, unmatched end event; don't.
    func end(_ interval: SignpostInterval)
}

// MARK: - Scoped Measurement

extension SignpostTracing {
    /// Measures a synchronous operation.
    ///
    /// The interval closes on the way out whether `operation` returns or throws.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - operation: Work to measure.
    /// - Returns: Whatever `operation` returns.
    public func measure<T>(_ name: StaticString,
                           category: SignpostCategory,
                           operation: () throws -> T) rethrows -> T {
        let interval = begin(name, category: category)
        defer { end(interval) }
        return try operation()
    }

    /// Measures an asynchronous operation.
    ///
    /// `isolation:` defaults to `#isolation`, so the call inherits the caller's
    /// actor. Wrapping `@MainActor` work therefore introduces **no actor hop**
    /// and imposes no `Sendable` requirement on `T` — which matters because the
    /// launch path is exactly where an accidental suspension would hurt most.
    ///
    /// The interval closes on return, on throw, and on cancellation.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - isolation: Actor to run on. Leave at the default.
    ///   - operation: Work to measure.
    /// - Returns: Whatever `operation` returns.
    public func measure<T>(_ name: StaticString,
                           category: SignpostCategory,
                           isolation _: isolated (any Actor)? = #isolation,
                           operation: () async throws -> sending T) async rethrows -> sending T {
        let interval = begin(name, category: category)
        defer { end(interval) }
        return try await operation()
    }
}

// MARK: - NoOpSignpostTracer

/// Records nothing.
///
/// Use for tests that don't assert on tracing, and as the fallback on platforms
/// without `os_signpost`.
public struct NoOpSignpostTracer: SignpostTracing {
    public init() {}

    public func emit(_: StaticString, category _: SignpostCategory) {}

    public func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval {
        .inactive(name: name, category: category)
    }

    public func end(_: SignpostInterval) {}
}
