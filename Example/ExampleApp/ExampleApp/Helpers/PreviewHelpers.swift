//
//  PreviewHelpers.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import ARCMetricsKit
import Foundation

// MARK: - Preview Sample Data

enum PreviewData {

    static func sampleMetricSummary(
        timeRange: String = "Jan 7-8, 2025",
        peakMemory: Double = 185.5,
        avgMemory: Double = 120.3,
        cpuTime: Double = 450.0,
        foregroundTime: Double = 3600.0,
        hangTime: Double = 1.25,
        launchTime: Double = 0.85,
        gpuTime: Double = 12.5,
        diskWrites: Double = 45.8,
        scrollHitch: Double = 3.2
    ) -> MetricSummary {
        var summary = MetricSummary(timeRange: timeRange)
        summary.peakMemoryUsageMB = peakMemory
        summary.averageMemoryUsageMB = avgMemory
        summary.cumulativeCPUTimeSeconds = cpuTime
        summary.foregroundTimeSeconds = foregroundTime
        summary.totalHangTimeSeconds = hangTime
        summary.averageLaunchTimeSeconds = launchTime
        summary.cumulativeGPUTimeSeconds = gpuTime
        summary.cumulativeDiskWritesMB = diskWrites
        summary.scrollHitchTimeRatio = scrollHitch
        summary.cellularDownloadMB = 25.5
        summary.cellularUploadMB = 5.2
        summary.wifiDownloadMB = 150.8
        summary.wifiUploadMB = 35.4
        summary.backgroundTimeSeconds = 1800.0
        return summary
    }

    static func sampleDiagnosticSummary(
        timeRange: String = "Jan 7-8, 2025",
        crashCount: Int = 2,
        hangCount: Int = 5
    ) -> DiagnosticSummary {
        var summary = DiagnosticSummary(timeRange: timeRange)
        summary.crashCount = crashCount
        summary.hangCount = hangCount
        summary.diskWriteExceptionCount = 1
        summary.cpuExceptionCount = 0
        return summary
    }

    static var sampleMetricSummaries: [MetricSummary] {
        [
            sampleMetricSummary(timeRange: "Jan 7-8, 2025", peakMemory: 185.5, gpuTime: 12.5, scrollHitch: 3.2),
            sampleMetricSummary(timeRange: "Jan 6-7, 2025", peakMemory: 165.2, gpuTime: 8.3, scrollHitch: 2.1),
            sampleMetricSummary(timeRange: "Jan 5-6, 2025", peakMemory: 210.8, gpuTime: 25.7, scrollHitch: 7.5)
        ]
    }

    static var sampleDiagnosticSummaries: [DiagnosticSummary] {
        [
            sampleDiagnosticSummary(timeRange: "Jan 7-8, 2025", crashCount: 2, hangCount: 5),
            sampleDiagnosticSummary(timeRange: "Jan 5-6, 2025", crashCount: 0, hangCount: 3)
        ]
    }
}

// MARK: - Preview ViewModel

extension MetricsViewModel {

    @MainActor static var preview: MetricsViewModel {
        let viewModel = MetricsViewModel()
        viewModel.metricSummaries = PreviewData.sampleMetricSummaries
        viewModel.diagnosticSummaries = PreviewData.sampleDiagnosticSummaries
        viewModel.lastUpdateTime = Date()
        return viewModel
    }

    @MainActor static var emptyPreview: MetricsViewModel {
        MetricsViewModel()
    }
}
