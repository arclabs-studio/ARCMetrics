//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import ARCMetrics
import SwiftUI

@main
struct ExampleApp: App {
    // MARK: - Private Properties

    @State private var metricsViewModel = MetricsViewModel()

    // MARK: - Initialization

    init() {
        MetricKitProvider.shared.startCollecting()

        print("ARCMetrics ExampleApp Started")
        print("MetricKit collection initialized")
        print("Metrics will be delivered every ~24 hours")
    }

    // MARK: - View

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(metricsViewModel)
        }
    }
}
