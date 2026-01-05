# ``ARCMetricsKit``

Native MetricKit integration for collecting technical performance metrics in Apple platform apps.

## Overview

ARCMetricsKit provides a simplified interface to Apple's MetricKit framework, making it easy to collect and analyze performance metrics from your production apps.

MetricKit automatically captures critical metrics like memory usage, CPU consumption, battery impact, launch times, and more—without requiring manual instrumentation.

## Key Features

- **Zero-overhead monitoring**: MetricKit runs in the background with minimal impact
- **Production-ready**: Metrics are collected from real users in production
- **Comprehensive coverage**: Memory, CPU, hangs, crashes, battery, network, and more
- **Privacy-preserving**: No PII collected, aggregated data only
- **Easy integration**: Simple API with callbacks

## Topics

### Getting Started

- <doc:GettingStarted>
- ``MetricKitProvider``

### Understanding Your Metrics

- <doc:UnderstandingMetrics>
- <doc:InstrumentsIntegration>
- ``MetricSummary``
- ``DiagnosticSummary``

### Troubleshooting

- <doc:TroubleshootingAndFAQ>
