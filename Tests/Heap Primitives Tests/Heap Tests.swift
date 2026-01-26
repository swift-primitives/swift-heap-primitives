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
        #expect(heap.count == 3)
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
        #expect(heap.count == 1)
        #expect(heap.peek == 42)
        #expect(try heap.pop() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test("Init from sequence")
    func initFromSequence() throws {
        var heap = Heap<Int>([5, 3, 7, 1], order: .ascending)

        #expect(heap.count == 4)
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
        #expect(heap.count == 3)
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
        #expect(heap.count == 1)
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
}
