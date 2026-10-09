//
//  SignpostEmission.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import Foundation

/// One signpost that ``MetricKitSignpostTracer`` emitted for a ``Tracing`` call.
///
/// Signposts cannot be read back from a test process, so the tracer reports each emission to an
/// optional observer. Tests use it to check what was emitted; production passes none.
struct SignpostEmission: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case begin
        case end
        case event
    }

    let kind: Kind
    let name: String
    let category: SignpostCategory
    let id: UInt64
}
