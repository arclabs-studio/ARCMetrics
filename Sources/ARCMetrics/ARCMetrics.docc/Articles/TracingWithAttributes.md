# Tracing with Attributes

Record spans that carry attributes, parent links and outcomes, and send them to MetricKit and another backend at once.

## Overview

``SignpostTracing`` records what `mxSignpost` can hold: a name, a category and a duration. ``Tracing`` records the same spans with more context, for backends that can store it, such as an OpenTelemetry exporter:

- **Attributes**: ``TraceAttributes``, a dictionary of ``TraceAttributeValue`` (string, integer, double or Boolean).
- **Parents**: a span can name the span it runs inside, so a backend can draw the tree.
- **Outcomes**: every span ends with ``TraceOutcome/ok`` or ``TraceOutcome/error(type:)``.

``MetricKitSignpostTracer`` conforms to both protocols. Through ``Tracing`` it keeps emitting signposts and ignores what signposts cannot carry.

## Tracing an Operation

``Tracing/trace(_:category:parent:attributes:operation:)`` begins a span, runs the operation and ends the span, whether the operation returns or throws:

```swift
let restaurants = try await tracer.trace("FetchAll", category: .persistence,
                                         attributes: ["store": "cloudkit"]) { _ in
    try await repository.fetchAll()
}
```

The async version inherits the caller's actor, so tracing `@MainActor` work adds no actor hop and no `Sendable` requirement on the result.

When the operation throws, the span ends with ``TraceOutcome/error(type:)`` carrying the error's **type name** only, for example `"URLError"`. The message never reaches a tracer, because messages can carry personal data.

## Nesting Spans

The operation receives its span. Pass it as `parent` to link a child:

```swift
try await tracer.trace("Import", category: .persistence) { importSpan in
    for batch in batches {
        try await tracer.trace("ImportBatch", category: .persistence, parent: importSpan,
                               attributes: ["size": batch.count]) { _ in
            try await store.insert(batch)
        }
    }
}
```

When begin and end cannot share a scope, use ``Tracing/begin(_:category:parent:attributes:)`` and ``Tracing/end(_:outcome:attributes:)``. End every span exactly once.

## Sending Spans to Several Backends

``TeeTracer`` forwards every call to each of its tracers with the same ``TraceSpan``, so every backend sees the same ID and start time. Because ``MetricKitSignpostTracer`` uses that ID as the `OSSignpostID`, an Instruments interval and an exported span can be matched:

```swift
let tracer = TeeTracer([MetricKitSignpostTracer(), otelTracer])
```

Use ``NoOpTracer`` where tracing is switched off.

## Keeping Attributes Free of Personal Data

Attributes leave the device in exporters. Never record names, email addresses, free text typed by the user, precise locations, or identifiers that follow a person across apps. Prefer counts, flags and enumerated values:

```swift
// Good: a count and a fixed vocabulary.
["results": 12, "source": "cache"]

// Never: user content.
["query": searchText]
```

## Testing Instrumented Code

The `ARCMetricsMocks` product ships `RecordingTracer`, which records every call:

```swift
let tracer = RecordingTracer()
let sut = Repository(tracer: tracer)

_ = try? await sut.fetchAll()

#expect(tracer.startedSpans == tracer.endedSpans)
```
