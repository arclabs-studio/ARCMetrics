//
//  MetricsLogger.swift
//  ARCMetrics
//
//  Created by ARC Labs Studio on 2026-10-06.
//

import ARCLogger

/// ARCLogger's `Logger` protocol, under a name that cannot collide.
///
/// From the iOS 27 SDK, `import MetricKit` re-exports `os`, so a bare `Logger`
/// is ambiguous against `os.Logger` in any file that imports MetricKit. The
/// qualified spelling `ARCLogger.Logger` does not work either: the module
/// ARCLogger also declares a type named `ARCLogger`, which shadows the module
/// name. This file imports ARCLogger alone, so `Logger` resolves uniquely here.
typealias MetricsLogger = Logger
