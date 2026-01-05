import SwiftUI

/// View with simulators for testing different performance scenarios
struct SimulatorsView: View {
    @State private var isSimulating = false
    @State private var simulationStatus = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("These simulators help you test how ARCMetricsKit captures different performance scenarios. MetricKit aggregates data over time, so effects may appear in payloads after 24-48 hours.")
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

    // MARK: - Simulators

    private func simulateMemoryPressure() {
        isSimulating = true
        simulationStatus = "Starting memory pressure simulation..."

        Task {
            let start = Date()

            // Allocate large arrays
            var arrays: [[Int]] = []
            for i in 0..<100 {
                let largeArray = Array(repeating: i, count: 1_000_000)
                arrays.append(largeArray)

                if i % 10 == 0 {
                    await MainActor.run {
                        simulationStatus = "Allocated \(i) large arrays..."
                    }
                }

                try? await Task.sleep(for: .milliseconds(50))
            }

            // Hold for a moment
            try? await Task.sleep(for: .seconds(2))

            // Release (arrays will be deallocated)
            arrays.removeAll()

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "✅ Memory pressure simulation completed in \(String(format: "%.1f", duration))s"
                isSimulating = false
            }
        }
    }

    private func simulateCPULoad() {
        isSimulating = true
        simulationStatus = "Starting CPU intensive simulation..."

        Task {
            let start = Date()

            // Perform heavy calculations
            await withTaskGroup(of: Void.self) { group in
                for threadIndex in 0..<4 {
                    group.addTask {
                        var result = 0
                        for i in 0..<10_000_000 {
                            result += i * threadIndex
                            result = result % 1000
                        }
                        // Prevent optimization
                        print("Thread \(threadIndex) result: \(result)")
                    }
                }
            }

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "✅ CPU simulation completed in \(String(format: "%.1f", duration))s"
                isSimulating = false
            }
        }
    }

    private func simulateMainThreadHang() {
        isSimulating = true
        simulationStatus = "⚠️ Hanging main thread for 1 second..."

        Task { @MainActor in
            let start = Date()

            // INTENTIONAL HANG - DO NOT DO THIS IN PRODUCTION
            Thread.sleep(forTimeInterval: 1.0)

            let duration = Date().timeIntervalSince(start)
            simulationStatus = "✅ Main thread hang completed (\(String(format: "%.1f", duration))s). This will be reported by MetricKit."
            isSimulating = false
        }
    }

    private func simulateBackgroundWork() {
        isSimulating = true
        simulationStatus = "Starting background work simulation..."

        Task {
            let start = Date()

            // Simulate background processing
            for i in 0..<50 {
                // Simulate some work
                await Task.detached {
                    var sum = 0
                    for j in 0..<100_000 {
                        sum += j
                    }
                    return sum
                }.value

                await MainActor.run {
                    simulationStatus = "Background task \(i + 1)/50..."
                }

                try? await Task.sleep(for: .milliseconds(100))
            }

            let duration = Date().timeIntervalSince(start)

            await MainActor.run {
                simulationStatus = "✅ Background work completed in \(String(format: "%.1f", duration))s"
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

            // Make multiple network requests
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
                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode) {
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
                simulationStatus = "✅ Network simulation completed in \(String(format: "%.1f", duration))s\nSuccessful: \(successCount), Failed: \(failureCount)"
                isSimulating = false
            }
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

#Preview {
    SimulatorsView()
}
