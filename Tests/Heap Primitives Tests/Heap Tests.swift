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
    @Test("Min-heap ordering (ascending)")
    func minHeapOrdering() throws {
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

    @Test("Max-heap ordering (descending)")
    func maxHeapOrdering() throws {
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

    @Test("Peek does not remove")
    func peekDoesNotRemove() {
        var heap = Heap<Int>(order: .ascending)
        heap.push(3)
        heap.push(1)
        heap.push(2)

        #expect(heap.peek == 1)
        #expect(heap.peek == 1)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("Empty heap")
    func emptyHeap() {
        var heap = Heap<Int>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(heap.peek == nil)
        #expect(heap.take == nil)
    }

    @Test("Single element")
    func singleElement() throws {
        var heap = Heap<Int>(order: .ascending)
        heap.push(42)
        #expect(heap.isEmpty == false)
        #expect(Int(bitPattern: heap.count) == 1)
        #expect(heap.peek == 42)
        #expect(try heap.pop() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test("Init from sequence")
    func initFromSequence() throws {
        var heap = Heap<Int>([5, 3, 7, 1], order: .ascending)

        #expect(Int(bitPattern: heap.count) == 4)
        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
    }

    @Test("Duplicate elements")
    func duplicateElements() {
        var heap = Heap<Int>(order: .ascending)
        heap.push(5)
        heap.push(5)
        heap.push(5)

        #expect(heap.take == 5)
        #expect(heap.take == 5)
        #expect(heap.take == 5)
        #expect(heap.take == nil)
    }
    @Test("drain(while:) drains some elements in priority order")
    func drainWhileSome() {
        var heap = Heap<Int>([5, 3, 8, 1, 4], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test("drain(while:) drains zero elements when predicate is immediately false")
    func drainWhileNone() {
        var heap = Heap<Int>([5, 3, 8], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("drain(while:) drains all elements when predicate is always true")
    func drainWhileAll() {
        var heap = Heap<Int>([5, 3, 8, 1], order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty)
    }

    @Test("drain(while:) on empty heap")
    func drainWhileEmpty() {
        var heap = Heap<Int>(order: .ascending)
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained.isEmpty)
    }
}

// MARK: - MinMax Heap Tests

@Suite("Heap.MinMax (Double-Ended)")
struct HeapMinMaxTests {
    @Test("MinMax heap provides both min and max")
    func minMaxHeapOrdering() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1, 9]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 9)

        #expect(try heap.min.pop() == 1)
        #expect(try heap.max.pop() == 9)
        #expect(heap.peek.min == 3)
        #expect(heap.peek.max == 7)
    }

    @Test("Pop min in order")
    func popMinInOrder() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1]

        #expect(try heap.min.pop() == 1)
        #expect(try heap.min.pop() == 3)
        #expect(try heap.min.pop() == 5)
        #expect(try heap.min.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop max in order")
    func popMaxInOrder() throws {
        var heap: Heap<Int>.MinMax = [5, 3, 7, 1]

        #expect(try heap.max.pop() == 7)
        #expect(try heap.max.pop() == 5)
        #expect(try heap.max.pop() == 3)
        #expect(try heap.max.pop() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Peek does not remove")
    func peekDoesNotRemove() {
        let heap: Heap<Int>.MinMax = [3, 1, 2]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 3)
        #expect(heap.peek.max == 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("Empty heap")
    func emptyHeap() {
        var heap = Heap<Int>.MinMax()
        #expect(heap.isEmpty == true)
        #expect(heap.peek.min == nil)
        #expect(heap.peek.max == nil)
        #expect(heap.min.take == nil)
        #expect(heap.max.take == nil)
    }

    @Test("Single element")
    func singleElement() throws {
        var heap: Heap<Int>.MinMax = [42]
        #expect(heap.isEmpty == false)
        #expect(Int(bitPattern: heap.count) == 1)
        #expect(heap.peek.min == 42)
        #expect(heap.peek.max == 42)
        #expect(try heap.min.pop() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test("Duplicate elements")
    func duplicateElements() {
        var heap: Heap<Int>.MinMax = [5, 5, 5]

        #expect(heap.min.take == 5)
        #expect(heap.min.take == 5)
        #expect(heap.min.take == 5)
        #expect(heap.min.take == nil)
    }

    @Test("Alternating min/max pops")
    func alternatingPops() throws {
        var heap: Heap<Int>.MinMax = [1, 2, 3, 4, 5]

        #expect(try heap.min.pop() == 1)
        #expect(try heap.max.pop() == 5)
        #expect(try heap.min.pop() == 2)
        #expect(try heap.max.pop() == 4)
        #expect(try heap.min.pop() == 3)
        #expect(heap.isEmpty == true)
    }

    @Test("drain(while:from: .min) drains smallest elements")
    func drainWhileMin() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1, 4]
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }, from: .min) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test("drain(while:from: .max) drains largest elements")
    func drainWhileMax() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1, 4]
        var drained: [Int] = []
        heap.drain(while: { $0 > 4 }, from: .max) { drained.append($0) }
        #expect(drained == [8, 5])
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("drain(while:from:) drains zero elements when predicate is immediately false")
    func drainWhileNone() {
        var heap: Heap<Int>.MinMax = [5, 3, 8]
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }, from: .min) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("drain(while:from:) drains all elements")
    func drainWhileAll() {
        var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
        var drained: [Int] = []
        heap.drain(while: { _ in true }, from: .min) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty)
    }
}
