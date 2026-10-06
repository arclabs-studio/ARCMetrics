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

#if os(iOS) || os(visionOS) || os(macOS)
import MetricKit
#endif

/// Emits spans that MetricKit aggregates and Instruments displays.
///
/// ## Why `mxSignpost` and not `OSSignposter`
///
/// On iOS and visionOS this emits through `mxSignpost` on a MetricKit log
/// handle: `MetricManager.logHandle(category:)` on iOS 27, and
/// `MXMetricManager.makeLogHandle(category:)` below it and on visionOS (where
/// `logHandle(category:)` is unavailable). macOS 27 does the same with
/// `MetricManager`. Apple's own guidance is explicit:
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
/// macOS before 27 gets no MetricKit aggregation, so it falls back to a plain
/// `OSLog` and `os_signpost`: still visible in Instruments.
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

    /// A log handle and how to emit on it.
    private struct Handle: Sendable {
        let log: OSLog
        /// Whether to emit through `mxSignpost`, which is what populates
        /// MetricKit's per-span CPU / memory / logical-writes measurements.
        let usesMetricKit: Bool
    }

    /// Lazily built log handles, one per category.
    ///
    /// Checked `Sendable`: both stored properties are constants, and the cache
    /// itself lives behind a lock.
    private final class HandleCache: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: [SignpostCategory: Handle]())
        private let mirrorSubsystem: String?

        init(mirrorSubsystem: String?) {
            self.mirrorSubsystem = mirrorSubsystem
        }

        func handle(for category: SignpostCategory) -> Handle {
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

        private func makeHandle(for category: SignpostCategory) -> Handle {
            if let mirrorSubsystem {
                #if os(iOS) || os(visionOS)
                let usesMetricKit = true
                #else
                let usesMetricKit = false
                #endif
                return Handle(log: OSLog(subsystem: mirrorSubsystem, category: category.rawValue),
                              usesMetricKit: usesMetricKit)
            }
            #if compiler(>=6.4) && (os(iOS) || os(macOS))
            if #available(iOS 27, macOS 27, *) {
                return Handle(log: MetricManager.logHandle(category: category.rawValue), usesMetricKit: true)
            }
            #endif
            #if os(iOS) || os(visionOS)
            return Handle(log: MXMetricManager.makeLogHandle(category: category.rawValue), usesMetricKit: true)
            #else
            return Handle(log: OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ARCMetrics",
                                     category: category.rawValue),
                          usesMetricKit: false)
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
        let handle = cache.handle(for: category)
        guard handle.log.signpostsEnabled else { return }
        Self.signpost(.event, on: handle, name: name, id: OSSignpostID(log: handle.log))
    }

    public func begin(_ name: StaticString, category: SignpostCategory) -> SignpostInterval {
        guard isEnabled else { return .inactive(name: name, category: category) }
        let handle = cache.handle(for: category)
        // Signposts can be switched off system-wide; skip the work rather than
        // pay for ID minting and an emission the system will discard.
        guard handle.log.signpostsEnabled else { return .inactive(name: name, category: category) }
        // Per-interval ID, never `.exclusive`: overlapping same-name intervals
        // are expected and `.exclusive` would mispair them.
        let id = OSSignpostID(log: handle.log)
        Self.signpost(.begin, on: handle, name: name, id: id)
        return SignpostInterval(name: name, category: category, rawID: id.rawValue, isActive: true)
    }

    public func end(_ interval: SignpostInterval) {
        guard interval.isActive else { return }
        let handle = cache.handle(for: interval.category)
        Self.signpost(.end, on: handle, name: interval.name, id: OSSignpostID(interval.rawID))
    }
}

// MARK: - Emission

extension MetricKitSignpostTracer {
    /// Single emission point, so the MetricKit-vs-`os_signpost` choice lives in
    /// exactly one place.
    private static func signpost(_ type: OSSignpostType, on handle: Handle, name: StaticString, id: OSSignpostID) {
        #if os(iOS) || os(visionOS) || os(macOS)
        if handle.usesMetricKit {
            // Only `mxSignpost` populates SignpostIntervalMetric's CPU / memory /
            // logical-writes measurements. `OSSignposter` on the same handle would
            // be Instruments-visible but yield no aggregate.
            mxSignpost(type, log: handle.log, name: name, signpostID: id)
            return
        }
        #endif
        os_signpost(type, log: handle.log, name: name, signpostID: id)
    }
}
