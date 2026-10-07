//
//  RecordingLogger.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-08-20.
//

import ARCLogger
import Foundation
import struct os.OSAllocatedUnfairLock

// The 6-parameter `log` signature is mandated by ARCLogger's `Logger` protocol,
// which disables the same rule at its own declaration site.
// swiftlint:disable function_parameter_count

/// Captures log lines so a test can assert on severity routing. Checked
/// `Sendable`: the entries live behind a lock.
final class RecordingLogger: Logger {
    struct Entry: Sendable, Equatable {
        let message: String
        let level: LogLevel
    }

    private let storage = OSAllocatedUnfairLock<[Entry]>(initialState: [])

    var entries: [Entry] {
        storage.withLock { $0 }
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
        storage.withLock { $0.append(Entry(message: message, level: level)) }
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
