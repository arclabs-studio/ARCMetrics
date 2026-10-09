//
//  TraceAttributeValue.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// A value attached to a span or an event.
///
/// The four cases map one-to-one onto OpenTelemetry's primitive attribute types. Literals work
/// directly:
///
/// ```swift
/// tracer.begin("Fetch", category: .network, attributes: ["count": 3, "cached": false])
/// ```
///
/// Attributes leave the device in exporters such as ARCMetricsOTel. Never put personal data in
/// them: no names, emails, free text, or coordinates.
public enum TraceAttributeValue: Sendable, Hashable {
    /// Text from a fixed vocabulary, for example `"cloudkit"`. Never user-entered text.
    case string(String)

    /// A whole number, such as a count.
    case int(Int)

    /// A floating-point number, such as a ratio.
    case double(Double)

    /// A flag.
    case bool(Bool)
}

/// Attributes keyed by name.
public typealias TraceAttributes = [String: TraceAttributeValue]

// MARK: - Literals

extension TraceAttributeValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension TraceAttributeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension TraceAttributeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension TraceAttributeValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}
