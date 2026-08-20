//
//  MetricKitSignpostTracer.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation
import os.log
import struct os.OSAllocatedUnfairLock
import os.signpost

#if os(iOS) || os(visionOS)
import MetricKit
#endif

/// Emits spans that MetricKit aggregates and Instruments displays.
///
/// ## Why `mxSignpost` and not `OSSignposter`
///
/// On iOS and visionOS this emits through `mxSignpost` on a log handle from
/// `MXMetricManager.makeLogHandle(category:)`. Apple's own guidance is explicit:
/// you *can* use `OSSignposter` with that handle, but **only `mxSignpost`
/// populates the measurement properties** — CPU time, memory, logical writes —
/// that make a span worth aggregating.
///
/// Because the handle is a real `OSLog`, one `mxSignpost` call serves both
/// audiences: MetricKit's 24-hour aggregate *and* the live Instruments trace.
///
/// `mxSignpost` is **not** deprecated in iOS 27. Only the read side changes
/// (`MXSignpostMetric` → `SignpostIntervalMetric`), so spans added now keep
/// working unchanged.
///
/// On other platforms there is no MetricKit, so this falls back to a plain
/// `OSLog` and `os_signpost`: still visible in Instruments, with no aggregation.
///
/// ## Overlapping intervals
///
/// Signpost IDs are minted per interval with `OSSignpostID(log:)`, never
/// `.exclusive`. Overlap is normal here — concurrent fetches, concurrent import
/// batches — and `.exclusive` would silently mispair them.
///
/// ## Topics
///
/// ### Creating a Tracer
/// - ``init(isEnabled:mirrorSubsystem:)``
public struct MetricKitSignpostTracer: SignpostTracing {
    // MARK: - Nested Types

    /// Lazily built log handles, one per category.
    private final class HandleCache: @unchecked Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: [SignpostCategory: OSLog]())
        private let mirrorSubsystem: String?

        init(mirrorSubsystem: String?) {
            self.mirrorSubsystem = mirrorSubsystem
        }

        func handle(for category: SignpostCategory) -> OSLog {
            if let cached = storage.withLock({ $0[category] }) {
                return cached
            }
            let made = makeHandle(for: category)
            return storage.withLock { cache in
                if let existing = cache[category] {
                    return existing
                }
                cache[category] = made
                return made
            }
        }

        private func makeHandle(for category: SignpostCategory) -> OSLog {
            if let mirrorSubsystem {
                return OSLog(subsystem: mirrorSubsystem, category: category.rawValue)
            }
            #if os(iOS) || os(visionOS)
            return MXMetricManager.makeLogHandle(category: category.rawValue)
            #else
            return OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ARCMetrics",
                         category: category.rawValue)
            #endif
        }
    }

    // MARK: - Properties

    private let isEnabled: Bool
    private let cache: HandleCache

    // MARK: - Initialization

    /// Creates a tracer.
    ///
    /// - Parameters:
    ///   - isEnabled: When `false`, every call is a no-op and ``begin(_:category:)``
    ///     returns an inactive token. Cheaper than wrapping call sites in `#if`.
    ///   - mirrorSubsystem: Emit to a plain `OSLog` under this subsystem instead
    ///     of the MetricKit handle. **Leave `nil`.** MetricKit does not aggregate
    ///     spans emitted elsewhere; this exists only if the MetricKit handle
    ///     proves impossible to filter in Instruments.
    public init(isEnabled: Bool = true, mirrorSubsystem: String? = nil) {
        self.isEnabled = isEnabled
        cache = HandleCache(mirrorSubsystem: mirrorSubsystem)
    }

    // MARK: - SignpostTracing

    public func emit(_ name: StaticString, category: SignpostCategory) {
        guard isEnabled else { return }
        let log = cache.handle(for: category)
        guard log.signpostsEnabled else { return }
        Self.signpost(.event, log: log, name: name, id: OSSignpostID(log: log))
    }

    public func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval {
        guard isEnabled else { return .inactive(name: name, category: category) }
        let log = cache.handle(for: category)
        // Signposts can be switched off system-wide; skip the work rather than
        // pay for ID minting and an emission the system will discard.
        guard log.signpostsEnabled else { return .inactive(name: name, category: category) }
        // Per-interval ID, never `.exclusive`: overlapping same-name intervals
        // are expected and `.exclusive` would mispair them.
        let id = OSSignpostID(log: log)
        Self.signpost(.begin, log: log, name: name, id: id)
        return SignpostInterval(name: name, category: category, rawID: id.rawValue, isActive: true)
    }

    public func end(_ interval: SignpostInterval) {
        guard interval.isActive else { return }
        let log = cache.handle(for: interval.category)
        Self.signpost(.end, log: log, name: interval.name, id: OSSignpostID(interval.rawID))
    }
}

// MARK: - Emission

extension MetricKitSignpostTracer {
    /// Single emission point, so the MetricKit-vs-`os_signpost` choice lives in
    /// exactly one place.
    private static func signpost(_ type: OSSignpostType, log: OSLog, name: StaticString, id: OSSignpostID) {
        #if os(iOS) || os(visionOS)
        // Only `mxSignpost` populates SignpostIntervalMetric's CPU / memory /
        // logical-writes measurements. `OSSignposter` on the same handle would
        // be Instruments-visible but yield no aggregate.
        mxSignpost(type, log: log, name: name, signpostID: id)
        #else
        os_signpost(type, log: log, name: name, signpostID: id)
        #endif
    }
}
