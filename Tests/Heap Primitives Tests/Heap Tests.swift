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
import Comparison_Primitives
import Index_Primitives
@testable import Heap_Primitives

// MARK: - Fixtures

/// A move-only element that conforms `Comparison.Protocol` (the borrowing `<`),
/// proving the tower carries `~Copyable` elements through push/pop/min.
private struct Job: ~Copyable, Comparison.`Protocol` {
    let priority: Int
    init(_ priority: Int) { self.priority = priority }
    static func < (lhs: borrowing Job, rhs: borrowing Job) -> Bool {
        lhs.priority < rhs.priority
    }
    static func == (lhs: borrowing Job, rhs: borrowing Job) -> Bool {
        lhs.priority == rhs.priority
    }
}

// MARK: - Heap (binary MIN priority queue — the ADT-tower W2 shape)
//
// The canonical `Heap<E>` rides the DIRECT heap column, so it is MOVE-ONLY for every
// element (Copyable or not). Observations are bound to locals before `#expect` — the
// property-access `#expect` form would otherwise require the move-only value to copy.

@Suite("Heap (binary min priority queue)")
struct HeapTests {

    @Test("empty heap reports isEmpty and count 0")
    func emptyState() {
        let heap = Heap<Int>()
        let empty = heap.isEmpty
        let count = heap.count
        #expect(empty)
        #expect(count == Index<Int>.Count(0))
    }

    @Test("push then pop yields elements in ascending (min-first) order")
    func minOrdering() {
        var heap = Heap<Int>()
        for value in [42, 3, 25, 7, 3, 19] { heap.push(value) }
        let nonEmpty = !heap.isEmpty
        let count = heap.count
        let minimum = heap.min
        #expect(nonEmpty)
        #expect(count == Index<Int>.Count(6))
        #expect(minimum == 3)

        var drained: [Int] = []
        while let next = heap.pop() { drained.append(next) }
        let empty = heap.isEmpty
        let overDrain = heap.pop()          // pop on empty -> nil (the convention)
        #expect(drained == [3, 3, 7, 19, 25, 42])
        #expect(empty)
        #expect(overDrain == nil)
    }

    @Test("min tracks the running minimum as elements arrive")
    func runningMinimum() {
        var heap = Heap<Int>()
        heap.push(9); let m0 = heap.min; #expect(m0 == 9)
        heap.push(4); let m1 = heap.min; #expect(m1 == 4)
        heap.push(8); let m2 = heap.min; #expect(m2 == 4)
        heap.push(1); let m3 = heap.min; #expect(m3 == 1)
        let popped = heap.pop()
        let m4 = heap.min
        #expect(popped == 1)          // Int? == Int-literal (Optional promotion)
        #expect(m4 == 4)
    }

    @Test("single-element heap: push, min, pop")
    func singleElement() {
        var heap = Heap<Int>()
        heap.push(17)
        let count = heap.count
        let minimum = heap.min
        #expect(count == Index<Int>.Count(1))
        #expect(minimum == 17)
        let popped = heap.pop()
        let empty = heap.isEmpty
        #expect(popped == 17)
        #expect(empty)
        let overDrain = heap.pop()
        #expect(overDrain == nil)
    }

    @Test("~Copyable elements flow through push/pop/min")
    func moveOnlyElements() {
        var heap = Heap<Job>()
        heap.push(Job(5))
        heap.push(Job(1))
        heap.push(Job(3))
        let peeked = heap.min.priority
        #expect(peeked == 1)
        // Consuming-unwrap the `~Copyable` Job? each pop (no borrow of Element?).
        var priorities: [Int] = []
        while let job = heap.pop() { priorities.append(job.priority) }
        let empty = heap.isEmpty
        #expect(priorities == [1, 3, 5])
        #expect(empty)
    }

    @Test("growth past the initial capacity preserves the heap invariant")
    func growthPreservesInvariant() {
        var heap = Heap<Int>(minimumCapacity: Index<Int>.Count(2))
        // Push descending so nearly every insert sifts to the root, forcing regrowth.
        for value in stride(from: 64, through: 1, by: -1) { heap.push(value) }
        let count = heap.count
        #expect(count == Index<Int>.Count(64))
        var previous = Int.min
        while let next = heap.pop() {
            #expect(next >= previous)
            previous = next
        }
    }
}
