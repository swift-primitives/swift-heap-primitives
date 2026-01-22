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

@Suite("Heap.Small")
struct HeapSmallTests {
    @Test("Init creates empty heap")
    func initCreatesEmpty() {
        let heap = Heap<Int>.Small<4>()
        #expect(heap.isEmpty == true)
        #expect(heap.count == 0)
        #expect(heap.isSpilled == false)
    }

    @Test("Push within inline capacity")
    func pushWithinInlineCapacity() {
        var heap = Heap<Int>.Small<4>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)

        #expect(heap.count == 4)
        #expect(heap.isSpilled == false)
    }

    @Test("Push spills to heap")
    func pushSpillsToHeap() {
        var heap = Heap<Int>.Small<4>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        #expect(heap.isSpilled == false)

        heap.push(5)  // Triggers spill
        #expect(heap.isSpilled == true)
        #expect(heap.count == 5)
    }

    @Test("Min-max ordering with inline storage")
    func minMaxOrderingInline() {
        var heap = Heap<Int>.Small<8>()
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 7)
        #expect(heap.isSpilled == false)
    }

    @Test("Min-max ordering after spill")
    func minMaxOrderingAfterSpill() {
        var heap = Heap<Int>.Small<2>()
        heap.push(5)
        heap.push(3)
        #expect(heap.isSpilled == false)

        heap.push(7)
        heap.push(1)
        #expect(heap.isSpilled == true)

        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 7)
    }

    @Test("Pop min in order inline")
    func popMinInOrderInline() throws {
        var heap = Heap<Int>.Small<8>()
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(try heap.popMin() == 1)
        #expect(try heap.popMin() == 3)
        #expect(try heap.popMin() == 5)
        #expect(try heap.popMin() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop min in order after spill")
    func popMinInOrderAfterSpill() throws {
        var heap = Heap<Int>.Small<2>()
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)
        #expect(heap.isSpilled == true)

        #expect(try heap.popMin() == 1)
        #expect(try heap.popMin() == 3)
        #expect(try heap.popMin() == 5)
        #expect(try heap.popMin() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop max in order")
    func popMaxInOrder() throws {
        var heap = Heap<Int>.Small<8>()
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(try heap.popMax() == 7)
        #expect(try heap.popMax() == 5)
        #expect(try heap.popMax() == 3)
        #expect(try heap.popMax() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() {
        var heap = Heap<Int>.Small<8>()
        #expect(throws: __Heap.Small.Error.empty) {
            try heap.popMin()
        }
        #expect(throws: __Heap.Small.Error.empty) {
            try heap.popMax()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() {
        var heap = Heap<Int>.Small<8>()
        #expect(heap.takeMin() == nil)
        #expect(heap.takeMax() == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() {
        var heap = Heap<Int>.Small<4>()
        heap.push(1)
        heap.push(2)
        heap.push(3)

        heap.clear()
        #expect(heap.isEmpty == true)
        #expect(heap.count == 0)
    }

    @Test("Clear after spill")
    func clearAfterSpill() {
        var heap = Heap<Int>.Small<2>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        #expect(heap.isSpilled == true)

        heap.clear()
        #expect(heap.isEmpty == true)
        #expect(heap.isSpilled == true)  // Still spilled, storage not reclaimed
    }

    @Test("Single element min equals max")
    func singleElementMinEqualsMax() {
        var heap = Heap<Int>.Small<4>()
        heap.push(42)

        #expect(heap.peekMin() == 42)
        #expect(heap.peekMax() == 42)
    }

    @Test("Heap grows after spill")
    func heapGrowsAfterSpill() {
        var heap = Heap<Int>.Small<2>()

        // Fill inline
        heap.push(1)
        heap.push(2)

        // Spill and grow
        for i in 3...20 {
            heap.push(i)
        }

        #expect(heap.count == 20)
        #expect(heap.isSpilled == true)
        #expect(heap.peekMin() == 1)
        #expect(heap.peekMax() == 20)
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() {
        var heap = Heap<Int>.Small<8>()
        heap.push(1)
        heap.push(2)
        heap.push(3)

        var sum = 0
        heap.forEach { element in
            sum += element
        }
        #expect(sum == 6)
    }

    @Test("forEach after spill")
    func forEachAfterSpill() {
        var heap = Heap<Int>.Small<2>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        #expect(heap.isSpilled == true)

        var sum = 0
        heap.forEach { element in
            sum += element
        }
        #expect(sum == 10)
    }

    @Test("withMin and withMax borrowing")
    func withMinMaxBorrowing() {
        var heap = Heap<Int>.Small<8>()
        heap.push(5)
        heap.push(3)
        heap.push(7)

        let minValue = heap.withMin { $0 * 2 }
        #expect(minValue == 6)

        let maxValue = heap.withMax { $0 * 2 }
        #expect(maxValue == 14)
    }

    @Test("Truncate reduces count inline")
    func truncateReducesCountInline() {
        var heap = Heap<Int>.Small<8>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)

        heap.truncate(to: 3)
        #expect(heap.count == 3)
    }

    @Test("Truncate after spill")
    func truncateAfterSpill() {
        var heap = Heap<Int>.Small<2>()
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)
        #expect(heap.isSpilled == true)

        heap.truncate(to: 3)
        #expect(heap.count == 3)
    }

    @Test("Capacity reflects storage type")
    func capacityReflectsStorageType() {
        var heap = Heap<Int>.Small<4>()
        #expect(heap.capacity == 4)  // Inline capacity

        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)  // Spills

        #expect(heap.isSpilled == true)
        #expect(heap.capacity >= 5)  // Heap capacity
    }
}

// MARK: - ~Copyable Element Tests

@Suite("Heap.Small with ~Copyable elements")
struct HeapSmallNonCopyableTests {
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

    @Test("Push and access ~Copyable elements inline")
    func pushAndAccessInline() {
        var heap = Heap<UniqueResource>.Small<8>()

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))

        #expect(heap.count == 3)
        #expect(heap.isSpilled == false)

        let minId = heap.withMin { $0.id }
        #expect(minId == 5)

        let maxId = heap.withMax { $0.id }
        #expect(maxId == 15)
    }

    @Test("Push and access ~Copyable elements after spill")
    func pushAndAccessAfterSpill() {
        var heap = Heap<UniqueResource>.Small<2>()

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))
        heap.push(UniqueResource(id: 1))

        #expect(heap.count == 4)
        #expect(heap.isSpilled == true)

        let minId = heap.withMin { $0.id }
        #expect(minId == 1)

        let maxId = heap.withMax { $0.id }
        #expect(maxId == 15)
    }

    @Test("forEach with ~Copyable elements")
    func forEachNonCopyable() {
        var heap = Heap<UniqueResource>.Small<8>()
        heap.push(UniqueResource(id: 3))
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))

        var ids: [Int] = []
        heap.forEach { element in
            ids.append(element.id)
        }
        #expect(Set(ids) == Set([1, 2, 3]))
    }

    @Test("Deinit properly cleans up ~Copyable elements inline")
    func deinitCleansUpInline() {
        var heap = Heap<UniqueResource>.Small<4>()
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }

    @Test("Deinit properly cleans up ~Copyable elements after spill")
    func deinitCleansUpAfterSpill() {
        var heap = Heap<UniqueResource>.Small<2>()
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        heap.push(UniqueResource(id: 4))
        #expect(heap.isSpilled == true)
        // heap goes out of scope - deinit should clean up properly
    }
}
