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
        print("ARCMetrics ExampleApp Started")
        print("Metrics will be delivered every ~24 hours")
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
