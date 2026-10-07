//
//  ReportFixtures.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-07.
//

// Same gate as production's `MetricManager` code: the types only exist in the
// iOS / macOS 27 SDKs, which ship with Swift 6.4.
#if compiler(>=6.4) && (os(iOS) || os(macOS))
import Foundation
import MetricKit
import Testing

/// Loads the `MetricManager` report fixtures in `Fixtures/MetricManager`.
///
/// `MetricReport` and `DiagnosticReport` have no public initializer, so every
/// test that needs one decodes a JSON capture. Fixture loading may fail
/// loudly: a missing or malformed fixture is a broken test, not a result.
@available(iOS 27, macOS 27, *) enum ReportFixtures {
    static func metricReport(_ name: String) throws -> MetricReport {
        try JSONDecoder().decode(MetricReport.self, from: data(name))
    }

    static func diagnosticReport(_ name: String) throws -> DiagnosticReport {
        try JSONDecoder().decode(DiagnosticReport.self, from: data(name))
    }

    private static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name,
                                                 withExtension: "json",
                                                 subdirectory: "Fixtures/MetricManager"))
        return try Data(contentsOf: url)
    }
}
#endif
