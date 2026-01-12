//
//  SimulatorsView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 2025-01-12.
//

import SwiftUI

struct SimulatorsView: View {
    // MARK: - Private Properties

    @State private var isSimulating = false
    @State private var simulationStatus = ""

    // MARK: - View

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        """
                        These simulators help you test how ARCMetrics captures different \
                        performance scenarios. MetricKit aggregates data over time, so \
                        effects may appear in payloads after 24-48 hours.
                        """
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("About Simulators")
                }

                Section {
                    SimulatorButton(
                        title: "Memory Pressure",
                        icon: "memorychip.fill",
                        color: .blue,
                        description: "Allocates large arrays to increase memory usage"
                    ) {
                        simulateMemoryPressure()
                    }

                    SimulatorButton(
                        title: "CPU Intensive Task",
                        icon: "cpu.fill",
                        color: .orange,
                        description: "Performs heavy calculations to increase CPU usage"
                    ) {
                        simulateCPULoad()
                    }

                    SimulatorButton(
                        title: "Main Thread Hang",
                        icon: "hourglass.fill",
                        color: .red,
                        description: "Blocks the main thread for 1 second"
                    ) {
                        simulateMainThreadHang()
                    }

                    SimulatorButton(
                        title: "Background Work",
                        icon: "gearshape.2.fill",
                        color: .purple,
                        description: "Simulates background processing"
                    ) {
                        simulateBackgroundWork()
                    }

                    SimulatorButton(
                        title: "Network Activity",
                        icon: "network",
                        color: .green,
                        description: "Simulates network requests"
                    ) {
                        simulateNetworkActivity()
                    }
                } header: {
                    Text("Performance Scenarios")
                }

                Section {
                    SimulatorButton(
                        title: "GPU Intensive Work",
                        icon: "gpu",
                        color: .cyan,
                        description: "Performs graphics-intensive operations"
                    ) {
                        simulateGPUWork()
                    }

                    SimulatorButton(
                        title: "Disk Write Activity",
                        icon: "externaldrive.fill",
                        color: .indigo,
                        description: "Writes data to disk repeatedly"
                    ) {
                        simulateDiskWrites()
                    }

                    SimulatorButton(
                        title: "Scroll Hitch Generator",
                        icon: "scroll.fill",
                        color: .pink,
                        description: "Creates scroll performance issues"
                    ) {
                        simulateScrollHitches()
                    }
                } header: {
                    Text("Additional Scenarios")
                }

                if !simulationStatus.isEmpty {
                    Section {
                        Text(simulationStatus)
                            .font(.caption)
                    } header: {
                        Text("Status")
                    }
                }
            }
            .navigationTitle("Simulators")
            .disabled(isSimulating)
            .overlay {
                if isSimulating {
                    ProgressView("Simulating...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Simulators

extension SimulatorsView {
    private func simulateMemoryPressure() {
        isSimulating = true
        simulationStatus = "Starting memory pressure simulation..."

        Task {
            let start = Date()
            var arrays: [[Int]] = []

            for index in 0 ..< 100 {
                let largeArray = Array(repeating: index, count: 1_000_000)
                arrays.append(largeArray)

                if index % 10 == 0 {
                    await MainActor.run {
                        simulationStatus = "Allocated \(index) large arrays..."
                    }
                }

                try? await Task.sleep(for: .milliseconds(50))
            }

            try? await Task.sleep(for: .seconds(2))
            arrays.removeAll()

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "Memory pressure simulation completed in \(String(format: "%.1f", duration))s"
                isSimulating = false
            }
        }
    }

    private func simulateCPULoad() {
        isSimulating = true
        simulationStatus = "Starting CPU intensive simulation..."

        Task {
            let start = Date()

            await withTaskGroup(of: Void.self) { group in
                for threadIndex in 0 ..< 4 {
                    group.addTask {
                        var result = 0
                        for iteration in 0 ..< 10_000_000 {
                            result += iteration * threadIndex
                            result = result % 1000
                        }
                        print("Thread \(threadIndex) result: \(result)")
                    }
                }
            }

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "CPU simulation completed in \(String(format: "%.1f", duration))s"
                isSimulating = false
            }
        }
    }

    private func simulateMainThreadHang() {
        isSimulating = true
        simulationStatus = "Hanging main thread for 1 second..."

        Task { @MainActor in
            let start = Date()
            Thread.sleep(forTimeInterval: 1.0)

            let duration = Date().timeIntervalSince(start)
            simulationStatus = "Main thread hang completed (\(String(format: "%.1f", duration))s)"
            isSimulating = false
        }
    }

    private func simulateBackgroundWork() {
        isSimulating = true
        simulationStatus = "Starting background work simulation..."

        Task {
            let start = Date()

            for taskIndex in 0 ..< 50 {
                await Task.detached {
                    var sum = 0
                    for iteration in 0 ..< 100_000 {
                        sum += iteration
                    }
                    return sum
                }.value

                await MainActor.run {
                    simulationStatus = "Background task \(taskIndex + 1)/50..."
                }

                try? await Task.sleep(for: .milliseconds(100))
            }

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "Background work completed in \(String(format: "%.1f", duration))s"
                isSimulating = false
            }
        }
    }

    private func simulateNetworkActivity() {
        isSimulating = true
        simulationStatus = "Starting network activity simulation..."

        Task {
            let start = Date()
            var successCount = 0
            var failureCount = 0

            let urls = [
                "https://api.github.com/users/github",
                "https://api.github.com/repos/apple/swift",
                "https://api.github.com/orgs/apple",
                "https://httpbin.org/get",
                "https://httpbin.org/uuid"
            ]

            for (index, urlString) in urls.enumerated() {
                guard let url = URL(string: urlString) else { continue }

                do {
                    let (_, response) = try await URLSession.shared.data(from: url)
                    let isSuccess = (response as? HTTPURLResponse)
                        .map { (200 ... 299).contains($0.statusCode) } ?? false
                    if isSuccess {
                        successCount += 1
                    } else {
                        failureCount += 1
                    }
                } catch {
                    failureCount += 1
                }

                await MainActor.run {
                    simulationStatus = "Network request \(index + 1)/\(urls.count)..."
                }

                try? await Task.sleep(for: .milliseconds(500))
            }

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                let durationStr = String(format: "%.1f", duration)
                simulationStatus = """
                Network simulation completed in \(durationStr)s
                Successful: \(successCount), Failed: \(failureCount)
                """
                isSimulating = false
            }
        }
    }

    private func simulateGPUWork() {
        isSimulating = true
        simulationStatus = "Starting GPU-intensive simulation..."

        Task { @MainActor in
            let start = Date()

            for batchIndex in 0 ..< 100 {
                var result: Double = 0
                for iteration in 0 ..< 100_000 {
                    result += sin(Double(iteration) * 0.001) * cos(Double(iteration) * 0.001)
                }
                _ = result

                if batchIndex % 20 == 0 {
                    simulationStatus = "GPU work batch \(batchIndex / 20 + 1)/5..."
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }

            let duration = Date().timeIntervalSince(start)
            let durationStr = String(format: "%.1f", duration)
            simulationStatus = "GPU simulation completed in \(durationStr)s"
            isSimulating = false
        }
    }

    private func simulateDiskWrites() {
        isSimulating = true
        simulationStatus = "Starting disk write simulation..."

        Task {
            let start = Date()
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            var totalBytesWritten = 0

            for fileIndex in 0 ..< 50 {
                let fileName = "arcmetrics_test_\(fileIndex).dat"
                let fileURL = tempDir.appendingPathComponent(fileName)
                let dataSize = 100 * 1024
                let data = Data((0 ..< dataSize).map { _ in UInt8.random(in: 0 ... 255) })

                do {
                    try data.write(to: fileURL)
                    totalBytesWritten += dataSize
                    try? fileManager.removeItem(at: fileURL)
                } catch {
                    print("Disk write error: \(error)")
                }

                await MainActor.run {
                    simulationStatus = "Writing file \(fileIndex + 1)/50..."
                }

                try? await Task.sleep(for: .milliseconds(50))
            }

            let duration = Date().timeIntervalSince(start)
            let mbWritten = Double(totalBytesWritten) / (1024 * 1024)

            await MainActor.run {
                let durationStr = String(format: "%.1f", duration)
                let mbStr = String(format: "%.1f", mbWritten)
                simulationStatus = """
                Disk simulation completed in \(durationStr)s
                Wrote \(mbStr) MB
                """
                isSimulating = false
            }
        }
    }

    private func simulateScrollHitches() {
        isSimulating = true
        simulationStatus = "Starting scroll hitch simulation..."

        Task { @MainActor in
            let start = Date()

            for frameIndex in 0 ..< 20 {
                var result: Double = 0
                for iteration in 0 ..< 500_000 {
                    result += Double(iteration).squareRoot()
                }
                _ = result

                Thread.sleep(forTimeInterval: 0.05)
                simulationStatus = "Simulating frame \(frameIndex + 1)/20..."
            }

            let duration = Date().timeIntervalSince(start)
            let durationStr = String(format: "%.1f", duration)
            simulationStatus = "Scroll hitch simulation completed in \(durationStr)s"
            isSimulating = false
        }
    }
}

// MARK: - Simulator Button

struct SimulatorButton: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color.gradient)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .foregroundColor(color)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Previews

#Preview {
    SimulatorsView()
}
