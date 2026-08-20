//
//  DiagnosticSummary.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import Foundation

/// A summary of diagnostic events collected by MetricKit.
///
/// `DiagnosticSummary` contains information about critical events like crashes,
/// hangs, and excessive resource usage that can help you identify and fix issues.
///
/// ## Topics
///
/// ### Reporting Period
/// - ``interval``
/// - ``timeRange``
///
/// ### Crash Information
/// - ``crashCount``
/// - ``crashes``
/// - ``CrashInfo``
///
/// ### Hang Information
/// - ``hangCount``
/// - ``hangs``
/// - ``HangInfo``
///
/// ### Resource Exceptions
/// - ``diskWriteExceptionCount``
/// - ``cpuExceptionCount``
public struct DiagnosticSummary: Sendable, Codable, Equatable, Hashable {
    // MARK: - Properties

    /// The period this summary covers, as machine-readable data.
    ///
    /// Prefer this over ``timeRange`` for anything other than display: it is
    /// locale-independent and comparable, which is what a consumer needs to
    /// deduplicate payloads across launches.
    ///
    /// `nil` only for summaries built through ``init(timeRange:)``.
    public let interval: DateInterval?

    /// Time range covered by this diagnostic summary, formatted for display.
    ///
    /// - Important: Locale-dependent. Never parse it — use ``interval``.
    public let timeRange: String

    // MARK: Crashes

    /// Number of crashes detected during the reporting period.
    ///
    /// Any value >0 requires immediate investigation.
    ///
    /// - Important: Crashes directly impact App Store ratings and user retention.
    public var crashCount: Int = 0

    /// Detailed information about each crash.
    ///
    /// Use this to identify crash patterns and root causes.
    public var crashes: [CrashInfo] = []

    // MARK: Hangs

    /// Number of hang events detected.
    ///
    /// Hangs occur when the main thread is blocked for >250ms.
    public var hangCount: Int = 0

    /// Detailed information about each hang event.
    public var hangs: [HangInfo] = []

    // MARK: Resource Exceptions

    /// Number of excessive disk write events.
    ///
    /// High disk write activity can drain battery and slow down the device.
    public var diskWriteExceptionCount: Int = 0

    /// Number of excessive CPU usage events.
    ///
    /// Sustained high CPU usage impacts battery life and device temperature.
    public var cpuExceptionCount: Int = 0

    // MARK: - Nested Types

    /// Detailed information about a crash.
    public struct CrashInfo: Sendable, Codable, Equatable, Hashable {
        /// The type of exception that caused the crash (e.g., "EXC_BAD_ACCESS").
        public let exceptionType: String?

        /// The signal that caused the crash (e.g., "SIGSEGV").
        public let signal: String?

        /// The termination reason provided by the system.
        public let terminationReason: String?

        /// Information about the virtual memory region involved in the crash.
        public let virtualMemoryRegionInfo: String?

        /// Creates crash detail.
        ///
        /// - Parameters:
        ///   - exceptionType: Exception type, e.g. `EXC_BAD_ACCESS`.
        ///   - signal: Signal name, e.g. `SIGSEGV`.
        ///   - terminationReason: System-supplied termination reason.
        ///   - virtualMemoryRegionInfo: Virtual memory region detail.
        public init(exceptionType: String?,
                    signal: String?,
                    terminationReason: String?,
                    virtualMemoryRegionInfo: String?) {
            self.exceptionType = exceptionType
            self.signal = signal
            self.terminationReason = terminationReason
            self.virtualMemoryRegionInfo = virtualMemoryRegionInfo
        }
    }

    /// Detailed information about a hang event.
    public struct HangInfo: Sendable, Codable, Equatable, Hashable {
        /// Duration of the hang, in seconds.
        ///
        /// **Severity levels:**
        /// - Minor: 0.25-0.5s (noticeable)
        /// - Moderate: 0.5-1.0s (frustrating)
        /// - Severe: >1.0s (unacceptable)
        public let duration: Double

        /// Creates hang detail.
        ///
        /// - Parameter duration: Hang duration in seconds.
        public init(duration: Double) {
            self.duration = duration
        }
    }

    // MARK: - Initialization

    /// Creates a summary covering `interval`.
    ///
    /// - Parameter interval: The period MetricKit aggregated these diagnostics over.
    public init(interval: DateInterval) {
        self.interval = interval
        timeRange = MetricSummary.displayString(for: interval)
    }

    /// Creates a summary from a pre-formatted display range, leaving
    /// ``interval`` `nil`.
    ///
    /// - Parameter timeRange: Display string for the reporting period.
    public init(timeRange: String) {
        interval = nil
        self.timeRange = timeRange
    }

    // MARK: - Decoding

    /// Decodes tolerantly: every field except ``timeRange`` falls back to its
    /// default when absent, so payloads archived by earlier releases — which had
    /// no ``interval`` — still decode.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeRange = try container.decode(String.self, forKey: .timeRange)
        interval = try container.decodeIfPresent(DateInterval.self, forKey: .interval)
        crashCount = try container.decodeIfPresent(Int.self, forKey: .crashCount) ?? 0
        crashes = try container.decodeIfPresent([CrashInfo].self, forKey: .crashes) ?? []
        hangCount = try container.decodeIfPresent(Int.self, forKey: .hangCount) ?? 0
        hangs = try container.decodeIfPresent([HangInfo].self, forKey: .hangs) ?? []
        diskWriteExceptionCount = try container.decodeIfPresent(Int.self, forKey: .diskWriteExceptionCount) ?? 0
        cpuExceptionCount = try container.decodeIfPresent(Int.self, forKey: .cpuExceptionCount) ?? 0
    }
}

// MARK: - CustomStringConvertible

extension DiagnosticSummary: CustomStringConvertible {
    public var description: String {
        """
        DiagnosticSummary(
          timeRange: \(timeRange)
          crashes: \(crashCount)
          hangs: \(hangCount)
          diskWriteExceptions: \(diskWriteExceptionCount)
          cpuExceptions: \(cpuExceptionCount)
        )
        """
    }
}
