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

@Suite("Heap.Inline")
struct HeapInlineTests {
    @Test("Init creates empty heap")
    func initCreatesEmpty() {
        let heap = Heap<Int>.Inline<8>()
        #expect(heap.isEmpty == true)
        #expect(heap.count == 0)
        #expect(heap.isFull == false)
    }

    @Test("Push returns inserted on success")
    func pushReturnsInserted() {
        var heap = Heap<Int>.Inline<8>()
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
    func pushReturnsOverflowWhenFull() {
        var heap = Heap<Int>.Inline<2>()
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
        #expect(heap.count == 2)
    }

    @Test("Min-max ordering")
    func minMaxOrdering() {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 7)
    }

    @Test("Pop min in order")
    func popMinInOrder() throws {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.popMin() == 1)
        #expect(try heap.popMin() == 3)
        #expect(try heap.popMin() == 5)
        #expect(try heap.popMin() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop max in order")
    func popMaxInOrder() throws {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(try heap.popMax() == 7)
        #expect(try heap.popMax() == 5)
        #expect(try heap.popMax() == 3)
        #expect(try heap.popMax() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() {
        var heap = Heap<Int>.Inline<8>()
        #expect(throws: __Heap.Inline.Error.empty) {
            try heap.popMin()
        }
        #expect(throws: __Heap.Inline.Error.empty) {
            try heap.popMax()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() {
        var heap = Heap<Int>.Inline<8>()
        #expect(heap.takeMin() == nil)
        #expect(heap.takeMax() == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.clear()
        #expect(heap.isEmpty == true)
        #expect(heap.count == 0)
    }

    @Test("Single element min equals max")
    func singleElementMinEqualsMax() {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(42)

        #expect(heap.peekMin() == 42)
        #expect(heap.peekMax() == 42)
    }

    @Test("Fill to capacity")
    func fillToCapacity() {
        var heap = Heap<Int>.Inline<4>()
        _ = heap.push(4)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(1)

        #expect(heap.isFull == true)
        #expect(heap.count == 4)
        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 4)
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() {
        var heap = Heap<Int>.Inline<8>()
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
    func withMinMaxBorrowing() {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let minValue = heap.withMin { $0 * 2 }
        #expect(minValue == 6)

        let maxValue = heap.withMax { $0 * 2 }
        #expect(maxValue == 14)
    }

    @Test("Truncate reduces count")
    func truncateReducesCount() {
        var heap = Heap<Int>.Inline<8>()
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(4)
        _ = heap.push(5)

        heap.truncate(to: 3)
        #expect(heap.count == 3)
    }

    @Test("Large capacity heap")
    func largeCapacityHeap() {
        var heap = Heap<Int>.Inline<16>()
        for i in 0..<16 {
            _ = heap.push(i)
        }
        #expect(heap.isFull == true)
        #expect(heap.peekMin() == 0)
        #expect(heap.peekMax() == 15)
    }
}

// MARK: - ~Copyable Element Tests

@Suite("Heap.Inline with ~Copyable elements")
struct HeapInlineNonCopyableTests {
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
        var heap = Heap<UniqueResource>.Inline<8>()

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
    func overflowPreservesElement() {
        var heap = Heap<UniqueResource>.Inline<2>()
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
        var heap = Heap<UniqueResource>.Inline<8>()
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
        var heap = Heap<UniqueResource>.Inline<4>()
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))
        _ = heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }
}
