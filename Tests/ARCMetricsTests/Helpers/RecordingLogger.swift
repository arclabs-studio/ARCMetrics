//
//  RecordingLogger.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import ARCLogger
import Foundation

// The 6-parameter `log` signature is mandated by ARCLogger's `Logger` protocol,
// which disables the same rule at its own declaration site.
// swiftlint:disable function_parameter_count

/// Captures log lines so a test can assert on severity routing.
final class RecordingLogger: Logger, @unchecked Sendable {
    struct Entry: Sendable, Equatable {
        let message: String
        let level: LogLevel
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.withLock { storage }
    }

    func entries(at level: LogLevel) -> [Entry] {
        entries.filter { $0.level == level }
    }

    func log(_ message: String,
             level: LogLevel,
             metadata _: [String: LogValue],
             file _: String,
             function _: String,
             line _: Int) {
        lock.withLock { storage.append(Entry(message: message, level: level)) }
    }
}

/// Discards everything. Keeps test output readable when the log is not the
/// thing under test.
struct SilentLogger: Logger {
    func log(_: String,
             level _: LogLevel,
             metadata _: [String: LogValue],
             file _: String,
             function _: String,
             line _: Int) {}
}

// swiftlint:enable function_parameter_count
