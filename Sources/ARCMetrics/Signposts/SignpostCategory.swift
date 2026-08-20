//
//  SignpostCategory.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-08-21.
//

import Foundation

/// The subsystem a span belongs to.
///
/// A category maps onto one `OSLog` handle, which is the unit Instruments and
/// MetricKit group by. Keep the set small: MetricKit throttles custom signpost
/// volume and drops the overflow silently.
///
/// The five constants below are the studio's shared vocabulary. Apps may add
/// their own — the type is `ExpressibleByStringLiteral`:
///
/// ```swift
/// extension SignpostCategory {
///     static let sync: SignpostCategory = "Sync"
/// }
/// ```
///
/// ## Topics
///
/// ### Standard Categories
/// - ``launch``
/// - ``persistence``
/// - ``network``
/// - ``media``
/// - ``intelligence``
public struct SignpostCategory: Sendable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
    // MARK: - Standard Categories

    /// App start-up work, up to the first frame.
    public static let launch: SignpostCategory = "Launch"

    /// Store opening, migration, fetches, writes.
    public static let persistence: SignpostCategory = "Persistence"

    /// Requests to remote services.
    public static let network: SignpostCategory = "Network"

    /// Image and video processing.
    public static let media: SignpostCategory = "Media"

    /// On-device or cloud model inference.
    public static let intelligence: SignpostCategory = "Intelligence"

    // MARK: - Properties

    public let rawValue: String

    // MARK: - Initialization

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }
}

// MARK: - CustomStringConvertible

extension SignpostCategory: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
