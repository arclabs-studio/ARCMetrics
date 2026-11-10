//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import ARCMetrics
import os
import SwiftUI

private let logger = Logger(subsystem: "com.arclabs.ARCMetrics.ExampleApp", category: "App")

@main
struct ExampleApp: App {
    // MARK: - Private Properties

    @State private var metricsViewModel = MetricsViewModel()

    // MARK: - Initialization

    init() {
        logger.info("ARCMetrics ExampleApp started")
        logger.info("Metrics will be delivered every ~24 hours")
    }

    // MARK: - View

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(metricsViewModel)
                .task { await metricsViewModel.observeMetrics() }
        }
    }
}
