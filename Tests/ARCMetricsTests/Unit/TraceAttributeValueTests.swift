//
//  TraceAttributeValueTests.swift
//  ARCMetricsTests
//
//  Created by ARC Labs Studio on 2026-10-09.
//

import ARCMetrics
import Foundation
import Testing

@Suite("Trace attribute values and spans", .tags(.unit), .timeLimit(.minutes(1))) struct TraceAttributeValueTests {
    // MARK: - Literal Conformances

    @Test("A string literal becomes .string") func stringLiteral() {
        // When
        let value: TraceAttributeValue = "hello"

        // Then
        #expect(value == .string("hello"))
    }

    @Test("An integer literal becomes .int, not .double") func integerLiteral() {
        // When
        let value: TraceAttributeValue = 42

        // Then
        #expect(value == .int(42))
        #expect(value != .double(42))
    }

    @Test("A float literal becomes .double") func floatLiteral() {
        // When
        let value: TraceAttributeValue = 2.5

        // Then
        #expect(value == .double(2.5))
    }

    @Test("A boolean literal becomes .bool", arguments: [true, false]) func booleanLiteral(flag: Bool) {
        // When — a literal can't be parameterised, so branch on the argument
        let value: TraceAttributeValue = flag ? true : false

        // Then
        #expect(value == .bool(flag))
    }

    @Test("A dictionary literal of mixed literals maps each value to its case") func attributesDictionary() {
        // When
        let attributes: TraceAttributes = ["a": "x", "b": 1, "c": 1.5, "d": true]

        // Then
        #expect(attributes == ["a": .string("x"), "b": .int(1), "c": .double(1.5), "d": .bool(true)])
    }

    // MARK: - TraceSpan

    @Test("Generated span ids are random, not a counter") func generatedIDsDiffer() {
        // When
        let ids = Set((0 ..< 50).map { _ in TraceSpan(name: "Work", category: .launch).id })

        // Then — 50 draws from a 64-bit space colliding is a bug
        #expect(ids.count == 50)
    }

    @Test("A span keeps the values it was created with") func spanKeepsValues() {
        // Given
        let start = Date(timeIntervalSince1970: 1000)

        // When
        let span = TraceSpan(name: "Work", category: .network, parentID: 7, id: 99, startTime: start)

        // Then
        #expect("\(span.name)" == "Work")
        #expect(span.category == .network)
        #expect(span.parentID == 7)
        #expect(span.id == 99)
        #expect(span.startTime == start)
    }

    @Test("A span defaults to no parent and a start time of now") func spanDefaults() {
        // Given
        let before = Date()

        // When
        let span = TraceSpan(name: "Work", category: .launch)

        // Then
        #expect(span.parentID == nil)
        #expect(span.startTime >= before)
        #expect(span.startTime <= Date())
    }

    @Test("Spans with identical fields are equal; names compare by text") func spanEquality() {
        // Given
        let start = Date(timeIntervalSince1970: 5)
        let base = TraceSpan(name: "Work", category: .launch, parentID: 1, id: 2, startTime: start)

        // Then
        #expect(base == TraceSpan(name: "Work", category: .launch, parentID: 1, id: 2, startTime: start))
        #expect(base != TraceSpan(name: "Other", category: .launch, parentID: 1, id: 2, startTime: start))
        #expect(base != TraceSpan(name: "Work", category: .media, parentID: 1, id: 2, startTime: start))
        #expect(base != TraceSpan(name: "Work", category: .launch, parentID: nil, id: 2, startTime: start))
        #expect(base != TraceSpan(name: "Work", category: .launch, parentID: 1, id: 3, startTime: start))
        let later = Date(timeIntervalSince1970: 6)
        #expect(base != TraceSpan(name: "Work", category: .launch, parentID: 1, id: 2, startTime: later))
    }
}
