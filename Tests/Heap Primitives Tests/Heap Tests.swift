// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing

@testable import Heap_Primitives

// MARK: - Single-Ended Heap Tests

@Suite("Heap (Single-Ended)")
struct HeapSingleEndedTests {
    @Test
    func `Min-heap ordering (ascending)`() throws {
        var heap = Heap<Int>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 1)  // Min at top
        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Max-heap ordering (descending)`() throws {
        var heap = Heap<Int>(order: .descending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 7)  // Max at top
        #expect(try heap.pop() == 7)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Peek does not remove`() {
        var heap = Heap<Int>(order: .ascending)
        heap.push(3)
        heap.push(1)
        heap.push(2)

        #expect(heap.peek == 1)
        #expect(heap.peek == 1)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `Empty heap`() {
        var heap = Heap<Int>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(heap.peek == nil)
        #expect(heap.take == nil)
    }

    @Test
    func `Single element`() throws {
        var heap = Heap<Int>(order: .ascending)
        heap.push(42)
        #expect(heap.isEmpty == false)
        #expect(Int(bitPattern: heap.count) == 1)
        #expect(heap.peek == 42)
        #expect(try heap.pop() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Init from sequence`() throws {
        var heap = Heap<Int>([5, 3, 7, 1], order: .ascending)

        #expect(Int(bitPattern: heap.count) == 4)
        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
    }

    @Test
    func `Duplicate elements`() {
        var heap = Heap<Int>(order: .ascending)
        heap.push(5)
        heap.push(5)
        heap.push(5)

        #expect(heap.take == 5)
        #expect(heap.take == 5)
        #expect(heap.take == 5)
        #expect(heap.take == nil)
    }
    @Test
    func `drain(while:) drains some elements in priority order`() {
        var heap = Heap<Int>([5, 3, 8, 1, 4], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test
    func `drain(while:) drains zero elements when predicate is immediately false`() {
        var heap = Heap<Int>([5, 3, 8], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:) drains all elements when predicate is always true`() {
        var heap = Heap<Int>([5, 3, 8, 1], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty)
    }

    @Test
    func `drain(while:) on empty heap`() {
        var heap = Heap<Int>(order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained.isEmpty)
    }
}

// MARK: - MinMax Heap Tests

// ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
// (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
// full template round. The gate self-restores when the MinMax targets
// return (canImport needs a CLEAN build to re-evaluate).
#if canImport(Heap_MinMax_Primitives)

@Suite("Heap.MinMax (Double-Ended)")
struct HeapMinMaxTests {
    @Test
    func `MinMax heap provides both min and max`() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1, 9]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 9)

        #expect(try heap.min.pop() == 1)
        #expect(try heap.max.pop() == 9)
        #expect(heap.peek.min == 3)
        #expect(heap.peek.max == 7)
    }

    @Test
    func `Pop min in order`() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1]

        #expect(try heap.min.pop() == 1)
        #expect(try heap.min.pop() == 3)
        #expect(try heap.min.pop() == 5)
        #expect(try heap.min.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Pop max in order`() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1]

        #expect(try heap.max.pop() == 7)
        #expect(try heap.max.pop() == 5)
        #expect(try heap.max.pop() == 3)
        #expect(try heap.max.pop() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Peek does not remove`() {
        let heap: Heap<Int>.MinMax = [3, 1, 2]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 3)
        #expect(heap.peek.max == 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `Empty heap`() {
        var heap = Heap<Int>.MinMax()
        #expect(heap.isEmpty == true)
        #expect(heap.peek.min == nil)
        #expect(heap.peek.max == nil)
        #expect(heap.min.take == nil)
        #expect(heap.max.take == nil)
    }

    @Test
    func `Single element`() throws {
        var heap: Heap<Int>.MinMax = [42]
        #expect(heap.isEmpty == false)
        #expect(Int(bitPattern: heap.count) == 1)
        #expect(heap.peek.min == 42)
        #expect(heap.peek.max == 42)
        #expect(try heap.min.pop() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `Duplicate elements`() {
        var heap: Heap<Int>.MinMax = [5, 5, 5]

        #expect(heap.min.take == 5)
        #expect(heap.min.take == 5)
        #expect(heap.min.take == 5)
        #expect(heap.min.take == nil)
    }

    @Test
    func `Alternating min/max pops`() throws {
        var heap: Heap<Int>.MinMax = [1, 2, 3, 4, 5]

        #expect(try heap.min.pop() == 1)
        #expect(try heap.max.pop() == 5)
        #expect(try heap.min.pop() == 2)
        #expect(try heap.max.pop() == 4)
        #expect(try heap.min.pop() == 3)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `drain(while:from: .min) drains smallest elements`() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1, 4]
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }, from: .min) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test
    func `drain(while:from: .max) drains largest elements`() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1, 4]
        var drained: [Int] = []
        heap.drain(while: { $0 > 4 }, from: .max) { drained.append($0) }
        #expect(drained == [8, 5])
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:from:) drains zero elements when predicate is immediately false`() {
        var heap: Heap<Int>.MinMax = [5, 3, 8]
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }, from: .min) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:from:) drains all elements`() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
        var drained: [Int] = []
        heap.drain(while: { _ in true }, from: .min) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty)
    }
}

#endif  // canImport(Heap_MinMax_Primitives)
