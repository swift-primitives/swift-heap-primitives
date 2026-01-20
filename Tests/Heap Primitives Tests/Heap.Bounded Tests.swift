// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import Heap_Primitives

@Suite("Heap.Bounded")
struct HeapBoundedTests {
    @Test("Init with capacity")
    func initWithCapacity() throws {
        let heap = try Heap<Int>.Bounded(capacity: 10)
        #expect(heap.isEmpty)
        #expect(heap.count == 0)
        #expect(heap.capacity == 10)
        #expect(!heap.isFull)
    }

    @Test("Init with negative capacity throws")
    func initNegativeCapacityThrows() {
        #expect(throws: __Heap.Bounded.Error.invalidCapacity) {
            _ = try Heap<Int>.Bounded(capacity: -1)
        }
    }

    @Test("Push returns inserted on success")
    func pushReturnsInserted() throws {
        var heap = try Heap<Int>.Bounded(capacity: 5)
        let outcome = heap.push(42)
        switch outcome {
        case .inserted:
            break  // Expected
        case .overflow:
            Issue.record("Expected .inserted but got .overflow")
        }
        #expect(heap.count == 1)
    }

    @Test("Push returns overflow when full")
    func pushReturnsOverflowWhenFull() throws {
        var heap = try Heap<Int>.Bounded(capacity: 2)
        _ = heap.push(1)
        _ = heap.push(2)
        #expect(heap.isFull)

        let outcome = heap.push(3)
        switch outcome {
        case .inserted:
            Issue.record("Expected .overflow but got .inserted")
        case .overflow(let element):
            #expect(element == 3)  // Element preserved
        }
        #expect(heap.count == 2)
    }

    @Test("Min-max ordering")
    func minMaxOrdering() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)
        _ = heap.push(9)

        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 9)
    }

    @Test("Pop min in order")
    func popMinInOrder() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.popMin() == 1)
        #expect(try heap.popMin() == 3)
        #expect(try heap.popMin() == 5)
        #expect(try heap.popMin() == 7)
        #expect(heap.isEmpty)
    }

    @Test("Pop max in order")
    func popMaxInOrder() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.popMax() == 7)
        #expect(try heap.popMax() == 5)
        #expect(try heap.popMax() == 3)
        #expect(try heap.popMax() == 1)
        #expect(heap.isEmpty)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        #expect(throws: __Heap.Bounded.Error.empty) {
            try heap.popMin()
        }
        #expect(throws: __Heap.Bounded.Error.empty) {
            try heap.popMax()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        #expect(heap.takeMin() == nil)
        #expect(heap.takeMax() == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.clear()
        #expect(heap.isEmpty)
        #expect(heap.count == 0)
        #expect(heap.capacity == 10)  // Capacity unchanged
    }

    @Test("Single element min equals max")
    func singleElementMinEqualsMax() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(42)

        #expect(heap.peekMin() == 42)
        #expect(heap.peekMax() == 42)
    }

    @Test("Copy-on-write semantics")
    func copyOnWriteSemantics() throws {
        var heap1 = try Heap<Int>.Bounded(capacity: 10)
        _ = heap1.push(5)
        _ = heap1.push(3)

        let heap2 = heap1  // Copy

        _ = heap1.push(1)

        #expect(heap1.count == 3)
        #expect(heap2.count == 2)
        #expect(heap1.peekMin() == 1)
        #expect(heap2.peekMin() == 3)
    }

    @Test("Init from sequence")
    func initFromSequence() throws {
        let heap = try Heap<Int>.Bounded([5, 3, 7, 1, 9], capacity: 10)
        #expect(heap.count == 5)
        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 9)
    }

    @Test("Init from sequence truncates to capacity")
    func initFromSequenceTruncates() throws {
        let heap = try Heap<Int>.Bounded([1, 2, 3, 4, 5], capacity: 3)
        #expect(heap.count == 3)
    }

    @Test("Sequence conformance")
    func sequenceConformance() throws {
        let heap = try Heap<Int>.Bounded([5, 3, 7, 1, 9], capacity: 10)
        var elements: [Int] = []
        for element in heap {
            elements.append(element)
        }
        #expect(elements.count == 5)
        #expect(Set(elements) == Set([1, 3, 5, 7, 9]))
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        var sum = 0
        heap.forEach { element in
            sum += element
        }
        #expect(sum == 6)
    }

    @Test("withMin and withMax borrowing")
    func withMinMaxBorrowing() throws {
        var heap = try Heap<Int>.Bounded(capacity: 10)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let minValue = heap.withMin { $0 * 2 }
        #expect(minValue == 6)

        let maxValue = heap.withMax { $0 * 2 }
        #expect(maxValue == 14)
    }

    @Test("Truncate reduces count")
    func truncateReducesCount() throws {
        var heap = try Heap<Int>.Bounded([1, 2, 3, 4, 5], capacity: 10)
        #expect(heap.count == 5)

        heap.truncate(to: 3)
        #expect(heap.count == 3)
    }

    @Test("Zero capacity heap")
    func zeroCapacityHeap() throws {
        var heap = try Heap<Int>.Bounded(capacity: 0)
        #expect(heap.isEmpty)
        #expect(heap.isFull)  // Zero capacity means full

        let outcome = heap.push(1)
        switch outcome {
        case .overflow(let element):
            #expect(element == 1)
        case .inserted:
            Issue.record("Expected overflow for zero-capacity heap")
        }
    }
}

// MARK: - ~Copyable Element Tests

@Suite("Heap.Bounded with ~Copyable elements")
struct HeapBoundedNonCopyableTests {
    /// A move-only resource for testing.
    struct UniqueResource: ~Copyable, Heap.Ordering {
        let id: Int

        init(id: Int) {
            self.id = id
        }

        static func isLessThan(_ lhs: borrowing UniqueResource, _ rhs: borrowing UniqueResource) -> Bool {
            lhs.id < rhs.id
        }
    }

    @Test("Push and access ~Copyable elements")
    func pushAndAccess() throws {
        var heap = try Heap<UniqueResource>.Bounded(capacity: 10)

        _ = heap.push(UniqueResource(id: 10))
        _ = heap.push(UniqueResource(id: 5))
        _ = heap.push(UniqueResource(id: 15))

        #expect(heap.count == 3)

        let minId = heap.withMin { $0.id }
        #expect(minId == 5)

        let maxId = heap.withMax { $0.id }
        #expect(maxId == 15)
    }

    @Test("Overflow preserves ~Copyable element")
    func overflowPreservesElement() throws {
        var heap = try Heap<UniqueResource>.Bounded(capacity: 2)
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))

        let outcome = heap.push(UniqueResource(id: 3))
        switch outcome {
        case .overflow(let resource):
            #expect(resource.id == 3)  // Element preserved
        case .inserted:
            Issue.record("Expected overflow")
        }
    }

    @Test("forEach with ~Copyable elements")
    func forEachNonCopyable() throws {
        var heap = try Heap<UniqueResource>.Bounded(capacity: 10)
        _ = heap.push(UniqueResource(id: 3))
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))

        var ids: [Int] = []
        heap.forEach { element in
            ids.append(element.id)
        }
        #expect(Set(ids) == Set([1, 2, 3]))
    }
}
