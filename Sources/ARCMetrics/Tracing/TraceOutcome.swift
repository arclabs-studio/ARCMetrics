//
//  TraceOutcome.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// How a span ended.
public enum TraceOutcome: Sendable, Hashable {
    /// The operation succeeded.
    case ok

    /// The operation failed.
    ///
    /// - Parameter type: The error's type name, for example `"URLError"`. Never the message,
    ///   which can carry personal data.
    case error(type: String)
}
