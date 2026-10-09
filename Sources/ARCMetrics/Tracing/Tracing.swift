//
//  Tracing.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// Records spans and events that carry attributes.
///
/// ``SignpostTracing`` can carry nothing but a name and a category, because that is all
/// `mxSignpost` accepts. `Tracing` adds attributes, parent links and outcomes, for backends that
/// can store them — an OpenTelemetry exporter, for example. ``MetricKitSignpostTracer`` conforms
/// too and ignores what signposts cannot hold, so one ``TeeTracer`` feeds both:
///
/// ```swift
/// let tracer = TeeTracer([MetricKitSignpostTracer(), otelTracer])
///
/// let restaurants = try await tracer.trace("FetchAll", category: .persistence,
///                                          attributes: ["source": "cloudkit"]) { _ in
///     try await repository.fetchAll()
/// }
/// ```
///
/// Attributes leave the device in some backends. Never put personal data in them.
///
/// ## Topics
///
/// ### Scoped Spans
/// - ``trace(_:category:parent:attributes:operation:)``
/// - ``trace(_:category:parent:attributes:isolation:operation:)``
///
/// ### Manual Spans
/// - ``begin(_:category:parent:attributes:)``
/// - ``end(_:outcome:attributes:)``
///
/// ### Implementing a Tracer
/// - ``start(_:attributes:)``
/// - ``event(_:category:attributes:)``
public protocol Tracing: Sendable {
    /// Records that `span` began. Call ``begin(_:category:parent:attributes:)`` instead, which
    /// creates the token and calls this.
    ///
    /// - Parameters:
    ///   - span: The token every tracer sees for this span.
    ///   - attributes: Attributes known when the span begins.
    func start(_ span: TraceSpan, attributes: TraceAttributes)

    /// Records that `span` ended.
    ///
    /// - Parameters:
    ///   - span: The token ``begin(_:category:parent:attributes:)`` returned. End it once.
    ///   - outcome: Whether the operation succeeded.
    ///   - attributes: Attributes learned while the span ran.
    func end(_ span: TraceSpan, outcome: TraceOutcome, attributes: TraceAttributes)

    /// Records a point-in-time event, with no duration.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the event.
    ///   - category: Subsystem the event belongs to.
    ///   - attributes: Attributes of the event.
    func event(_ name: StaticString, category: SignpostCategory, attributes: TraceAttributes)
}

// MARK: - Spans

extension Tracing {
    /// Opens a span.
    ///
    /// Prefer ``trace(_:category:parent:attributes:operation:)``, which cannot leak an
    /// unended span.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - parent: The enclosing span, if any.
    ///   - attributes: Attributes known when the span begins.
    /// - Returns: The token to hand to ``end(_:outcome:attributes:)``.
    public func begin(_ name: StaticString,
                      category: SignpostCategory,
                      parent: TraceSpan? = nil,
                      attributes: TraceAttributes = [:]) -> TraceSpan {
        let span = TraceSpan(name: name, category: category, parentID: parent?.id)
        start(span, attributes: attributes)
        return span
    }

    /// Traces a synchronous operation.
    ///
    /// The span ends with ``TraceOutcome/ok`` when `operation` returns, and with
    /// ``TraceOutcome/error(type:)`` — the error's type name, never its message — when it throws.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - parent: The enclosing span, if any.
    ///   - attributes: Attributes known when the span begins.
    ///   - operation: Work to trace. Receives the span, to pass as `parent` to nested spans.
    /// - Returns: Whatever `operation` returns.
    public func trace<T>(_ name: StaticString,
                         category: SignpostCategory,
                         parent: TraceSpan? = nil,
                         attributes: TraceAttributes = [:],
                         operation: (TraceSpan) throws -> T) rethrows -> T {
        let span = begin(name, category: category, parent: parent, attributes: attributes)
        do {
            let result = try operation(span)
            end(span, outcome: .ok, attributes: [:])
            return result
        } catch {
            end(span, outcome: .failure(error), attributes: [:])
            throw error
        }
    }

    /// Traces an asynchronous operation.
    ///
    /// `isolation:` defaults to `#isolation`, so the call inherits the caller's actor: no actor
    /// hop, and no `Sendable` requirement on `T`. The span ends on return and on throw; an
    /// operation that throws `CancellationError` ends it as `error(type: "CancellationError")`.
    ///
    /// - Parameters:
    ///   - name: Compile-time literal identifying the span.
    ///   - category: Subsystem the span belongs to.
    ///   - parent: The enclosing span, if any.
    ///   - attributes: Attributes known when the span begins.
    ///   - isolation: Actor to run on. Leave at the default.
    ///   - operation: Work to trace. Receives the span, to pass as `parent` to nested spans.
    /// - Returns: Whatever `operation` returns.
    public func trace<T>(_ name: StaticString,
                         category: SignpostCategory,
                         parent: TraceSpan? = nil,
                         attributes: TraceAttributes = [:],
                         isolation _: isolated (any Actor)? = #isolation,
                         operation: (TraceSpan) async throws -> sending T) async rethrows -> sending T {
        let span = begin(name, category: category, parent: parent, attributes: attributes)
        do {
            let result = try await operation(span)
            end(span, outcome: .ok, attributes: [:])
            return result
        } catch {
            end(span, outcome: .failure(error), attributes: [:])
            throw error
        }
    }
}

// MARK: - Outcome

extension TraceOutcome {
    /// The outcome for `error`: its type name only, since messages can carry personal data.
    static func failure(_ error: any Error) -> TraceOutcome {
        .error(type: String(describing: type(of: error)))
    }
}
