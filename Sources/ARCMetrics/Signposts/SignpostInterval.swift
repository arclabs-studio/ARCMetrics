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
/// Opaque by design: nothing outside the package should synthesise one
/// (`ARCMetricsMocks` does, through the `package` initialiser).
public struct SignpostInterval: Sendable {
    // MARK: - Properties

    /// The literal the interval opened with.
    package let name: StaticString

    /// The category whose log handle the interval was emitted on.
    package let category: SignpostCategory

    /// The underlying `OSSignpostID` value.
    ///
    /// Stored raw so this type stays available on platforms without `os_signpost`.
    package let rawID: UInt64

    /// Whether ``SignpostTracing/end(_:)`` should emit anything.
    ///
    /// `false` when the tracer is disabled, so `end` becomes a cheap no-op
    /// rather than a branch at every call site.
    package let isActive: Bool

    // MARK: - Initialization

    /// Creates a token.
    ///
    /// `package` so `ARCMetricsMocks` can mint tokens without making this
    /// constructor public API.
    package init(name: StaticString, category: SignpostCategory, rawID: UInt64, isActive: Bool) {
        self.name = name
        self.category = category
        self.rawID = rawID
        self.isActive = isActive
    }

    /// A token that emits nothing when ended.
    static func inactive(name: StaticString, category: SignpostCategory) -> SignpostInterval {
        SignpostInterval(name: name, category: category, rawID: 0, isActive: false)
    }
}
