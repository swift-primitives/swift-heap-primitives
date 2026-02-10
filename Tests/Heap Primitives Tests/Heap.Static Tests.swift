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

// MARK: - Heap.Static Tests (Single-Ended)

@Suite("Heap.Static (Single-Ended)")
struct HeapStaticTests {
    @Test("Init creates empty heap")
    func initCreatesEmpty() {
        let heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
        #expect(heap.isFull == false)
    }

    @Test("Push returns inserted on success")
    func pushReturnsInserted() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        let outcome = heap.push(42)
        switch outcome {
        case .inserted:
            break  // Expected
        case .overflow:
            Issue.record("Expected .inserted but got .overflow")
        }
        #expect(Int(bitPattern: heap.count) == 1)
    }

    @Test("Push returns overflow when full")
    func pushReturnsOverflowWhenFull() {
        var heap = Heap<Int>.Static<2>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        #expect(heap.isFull == true)

        let outcome = heap.push(3)
        switch outcome {
        case .inserted:
            Issue.record("Expected .overflow but got .inserted")
        case .overflow(let element):
            #expect(element == 3)  // Element preserved
        }
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test("Min-heap ordering (ascending)")
    func minHeapOrdering() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test("Max-heap ordering (descending)")
    func maxHeapOrdering() {
        var heap = Heap<Int>.Static<8>(order: .descending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(heap.peek == 7)  // Max at top
    }

    @Test("Pop in order (min-heap)")
    func popMinInOrder() throws {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop in order (max-heap)")
    func popMaxInOrder() throws {
        var heap = Heap<Int>.Static<8>(order: .descending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.pop() == 7)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(throws: Heap<Int>.Static<8>.Error.empty) {
            try heap.pop()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(heap.take == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
    }

    @Test("Single element")
    func singleElement() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(42)

        #expect(heap.peek == 42)
        #expect(Int(bitPattern: heap.count) == 1)
    }

    @Test("Fill to capacity")
    func fillToCapacity() {
        var heap = Heap<Int>.Static<4>(order: .ascending)
        _ = heap.push(4)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(1)

        #expect(heap.isFull == true)
        #expect(Int(bitPattern: heap.count) == 4)
        #expect(heap.peek == 1)  // Min at top
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        var sum = 0
        heap.forEach { element in
            sum += element
        }
        #expect(sum == 6)
    }

    @Test("withPriority borrowing access")
    func withPriorityBorrowing() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test("Truncate reduces count")
    func truncateReducesCount() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(4)
        _ = heap.push(5)

        heap.truncate(to: 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("Large capacity heap")
    func largeCapacityHeap() {
        var heap = Heap<Int>.Static<16>(order: .ascending)
        for i in 0..<16 {
            _ = heap.push(i)
        }
        #expect(heap.isFull == true)
        #expect(heap.peek == 0)  // Min at top
    }
}

// MARK: - ~Copyable Element Tests

@Suite("Heap.Static with ~Copyable elements")
struct HeapStaticNonCopyableTests {
    /// A move-only resource for testing.
    struct UniqueResource: ~Copyable, Comparison_Primitives.Comparison.`Protocol` {
        let id: Int

        init(id: Int) {
            self.id = id
        }

        static func < (lhs: borrowing UniqueResource, rhs: borrowing UniqueResource) -> Bool {
            lhs.id < rhs.id
        }

        static func == (lhs: borrowing UniqueResource, rhs: borrowing UniqueResource) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Test("Push and access ~Copyable elements")
    func pushAndAccess() {
        var heap = Heap<UniqueResource>.Static<8>(order: .ascending)

        _ = heap.push(UniqueResource(id: 10))
        _ = heap.push(UniqueResource(id: 5))
        _ = heap.push(UniqueResource(id: 15))

        #expect(Int(bitPattern: heap.count) == 3)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test("Overflow preserves ~Copyable element")
    func overflowPreservesElement() {
        var heap = Heap<UniqueResource>.Static<2>(order: .ascending)
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
    func forEachNonCopyable() {
        var heap = Heap<UniqueResource>.Static<8>(order: .ascending)
        _ = heap.push(UniqueResource(id: 3))
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))

        var ids: [Int] = []
        heap.forEach { element in
            ids.append(element.id)
        }
        #expect(Set(ids) == Set([1, 2, 3]))
    }

    @Test("Deinit properly cleans up ~Copyable elements")
    func deinitCleansUp() {
        // This test ensures no crash on deallocation
        var heap = Heap<UniqueResource>.Static<4>(order: .ascending)
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))
        _ = heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }
}

// Note: Tests for Heap.MinMax.Static will be added when that variant is fully implemented.
