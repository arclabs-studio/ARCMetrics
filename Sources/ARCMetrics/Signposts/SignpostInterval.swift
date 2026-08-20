//
//  SignpostInterval.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation

/// An in-flight span, returned by ``SignpostTracing/begin(_:category:)`` and
/// consumed by ``SignpostTracing/end(_:)``.
///
/// Carries the `StaticString` because the signpost API requires the *same*
/// literal to close an interval that opened it — the token is what saves every
/// call site from repeating the name and getting it wrong.
///
/// Opaque by design: nothing outside the package should synthesise one.
public struct SignpostInterval: Sendable {
    // MARK: - Properties

    /// The literal the interval opened with.
    let name: StaticString

    /// The category whose log handle the interval was emitted on.
    let category: SignpostCategory

    /// The underlying `OSSignpostID` value.
    ///
    /// Stored raw so this type stays available on platforms without `os_signpost`.
    let rawID: UInt64

    /// Whether ``SignpostTracing/end(_:)`` should emit anything.
    ///
    /// `false` when the tracer is disabled, so `end` becomes a cheap no-op
    /// rather than a branch at every call site.
    let isActive: Bool

    /// A token that emits nothing when ended.
    static func inactive(name: StaticString, category: SignpostCategory) -> SignpostInterval {
        SignpostInterval(name: name, category: category, rawID: 0, isActive: false)
    }
}
