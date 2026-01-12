//
//  MetricSummary.swift
//  ARCMetricsKit
//
//  Created by ARC Labs Studio on 2025-01-05.
//

import Foundation

/// A simplified summary of technical performance metrics collected by MetricKit.
///
/// `MetricSummary` aggregates the most important metrics from MetricKit payloads into
/// an easy-to-use format. Apple delivers these summaries approximately every 24 hours.
///
/// ## Topics
///
/// ### Memory Metrics
/// - ``peakMemoryUsageMB``
/// - ``averageMemoryUsageMB``
///
/// ### CPU Metrics
/// - ``cumulativeCPUTimeSeconds``
/// - ``averageCPUPercentage``
///
/// ### Responsiveness
/// - ``totalHangTimeSeconds``
/// - ``averageLaunchTimeSeconds``
///
/// ### Usage Time
/// - ``foregroundTimeSeconds``
/// - ``backgroundTimeSeconds``
///
/// ### Network Usage
/// - ``cellularDownloadMB``
/// - ``cellularUploadMB``
/// - ``wifiDownloadMB``
/// - ``wifiUploadMB``
///
/// ### GPU Metrics
/// - ``cumulativeGPUTimeSeconds``
///
/// ### Disk I/O
/// - ``cumulativeDiskWritesMB``
///
/// ### Animation
/// - ``scrollHitchTimeRatio``
public struct MetricSummary: Sendable, Codable, Equatable, Hashable {
    // MARK: - Properties

    /// Time range covered by this metric summary.
    ///
    /// MetricKit aggregates metrics over time windows, typically 24 hours.
    public let timeRange: String

    // MARK: Memory

    /// Peak memory usage during the reporting period, in megabytes.
    ///
    /// This represents the maximum amount of memory your app used at any point.
    /// High values may indicate memory leaks or inefficient caching.
    ///
    /// **Typical values:**
    /// - Small apps: 50-100 MB
    /// - Medium apps: 100-200 MB
    /// - Large apps: 200-400 MB
    ///
    /// - Important: Apps using >500 MB risk termination on older devices.
    public var peakMemoryUsageMB: Double = 0

    /// Average memory usage while the app was suspended, in megabytes.
    ///
    /// Lower values are better for battery life and reduce the likelihood of
    /// your app being terminated in the background.
    public var averageMemoryUsageMB: Double = 0

    // MARK: CPU

    /// Total CPU time consumed by your app, in seconds.
    ///
    /// This is the sum of all CPU time across all threads. Higher values
    /// indicate more processing work and potential battery drain.
    public var cumulativeCPUTimeSeconds: Double = 0

    /// Average CPU usage as a percentage of available CPU.
    ///
    /// Calculated as `(cumulativeCPUTime / foregroundTime) × 100`.
    ///
    /// **Typical values:**
    /// - Idle: <5%
    /// - Light usage: 5-20%
    /// - Heavy usage: 20-50%
    /// - Intensive: >50%
    ///
    /// - Note: Values >100% indicate multi-threaded CPU usage.
    public var averageCPUPercentage: Double {
        guard foregroundTimeSeconds > 0 else { return 0 }
        return (cumulativeCPUTimeSeconds / foregroundTimeSeconds) * 100
    }

    // MARK: Hangs

    /// Total time the app was unresponsive (hangs), in seconds.
    ///
    /// Hangs occur when the main thread is blocked for >250ms. Any value above 0
    /// indicates performance issues that affect user experience.
    ///
    /// **Target:** 0 seconds
    ///
    /// - Warning: Frequent hangs lead to poor App Store reviews and increased
    ///            uninstall rates.
    public var totalHangTimeSeconds: Double = 0

    // MARK: App Time

    /// Total time the app spent in the foreground, in seconds.
    public var foregroundTimeSeconds: Double = 0

    /// Total time the app spent in the background, in seconds.
    public var backgroundTimeSeconds: Double = 0

    // MARK: Launch

    /// Average time to first draw (launch time), in seconds.
    ///
    /// Measured from app launch to when the first frame is rendered.
    ///
    /// **Typical values:**
    /// - Fast: <0.5s
    /// - Acceptable: 0.5-1.0s
    /// - Slow: 1.0-2.0s
    /// - Very slow: >2.0s
    ///
    /// - Important: Launch times >2s significantly impact user perception.
    public var averageLaunchTimeSeconds: Double = 0

    // MARK: Network

    /// Data downloaded over cellular network, in megabytes.
    public var cellularDownloadMB: Double = 0

    /// Data uploaded over cellular network, in megabytes.
    public var cellularUploadMB: Double = 0

    /// Data downloaded over WiFi, in megabytes.
    public var wifiDownloadMB: Double = 0

    /// Data uploaded over WiFi, in megabytes.
    public var wifiUploadMB: Double = 0

    // MARK: GPU

    /// Total GPU time consumed by your app, in seconds.
    ///
    /// High GPU usage indicates graphics-intensive operations and can impact
    /// battery life significantly.
    public var cumulativeGPUTimeSeconds: Double = 0

    // MARK: Disk I/O

    /// Total logical disk writes, in megabytes.
    ///
    /// High disk write activity can slow down the device and drain battery.
    /// Consider caching strategies and batch writes to reduce this metric.
    public var cumulativeDiskWritesMB: Double = 0

    // MARK: Animation

    /// Scroll hitch time ratio as a percentage.
    ///
    /// A hitch occurs when a frame takes longer than expected to render during scrolling.
    /// Lower values indicate smoother scrolling performance.
    ///
    /// **Target:** < 5%
    public var scrollHitchTimeRatio: Double = 0

    // MARK: - Initialization

    public init(timeRange: String) {
        self.timeRange = timeRange
    }
}

// MARK: - CustomStringConvertible

extension MetricSummary: CustomStringConvertible {
    public var description: String {
        """
        MetricSummary(
          timeRange: \(timeRange)
          memory: peak=\(String(format: "%.1f", peakMemoryUsageMB))MB, avg=\(String(
              format: "%.1f",
              averageMemoryUsageMB
          ))MB
          cpu: \(String(format: "%.1f", averageCPUPercentage))%
          hangs: \(String(format: "%.2f", totalHangTimeSeconds))s
          launch: \(String(format: "%.2f", averageLaunchTimeSeconds))s
          network: cellular=\(String(format: "%.1f", cellularDownloadMB))MB↓ \(String(
              format: "%.1f",
              cellularUploadMB
          ))MB↑
        )
        """
    }
}
