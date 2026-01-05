import Foundation

/// A summary of diagnostic events collected by MetricKit.
///
/// `DiagnosticSummary` contains information about critical events like crashes,
/// hangs, and excessive resource usage that can help you identify and fix issues.
///
/// ## Topics
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
public struct DiagnosticSummary: Sendable {

    // MARK: - Properties

    /// Time range covered by this diagnostic summary.
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
    public struct CrashInfo: Sendable {
        /// The type of exception that caused the crash (e.g., "EXC_BAD_ACCESS").
        public let exceptionType: String?

        /// The signal that caused the crash (e.g., "SIGSEGV").
        public let signal: String?

        /// The termination reason provided by the system.
        public let terminationReason: String?

        /// Information about the virtual memory region involved in the crash.
        public let virtualMemoryRegionInfo: String?
    }

    /// Detailed information about a hang event.
    public struct HangInfo: Sendable {
        /// Duration of the hang, in seconds.
        ///
        /// **Severity levels:**
        /// - Minor: 0.25-0.5s (noticeable)
        /// - Moderate: 0.5-1.0s (frustrating)
        /// - Severe: >1.0s (unacceptable)
        public let duration: Double
    }

    // MARK: - Initialization

    public init(timeRange: String) {
        self.timeRange = timeRange
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
