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
import Index_Primitives_Test_Support
@testable import Heap_Primitives

@Suite("Heap.Small (Single-Ended)")
struct HeapSmallTests {
    @Test("Init creates empty heap")
    func initCreatesEmpty() {
        let heap = Heap<Int>.Small<4>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
        #expect(heap.isSpilled == false)
    }

    @Test("Push within inline capacity")
    func pushWithinInlineCapacity() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)

        #expect(Int(bitPattern: heap.count) == 4)
        #expect(heap.isSpilled == false)
    }

    @Test("Push spills to heap")
    func pushSpillsToHeap() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        #expect(heap.isSpilled == false)

        heap.push(5)  // Triggers spill
        #expect(heap.isSpilled == true)
        #expect(Int(bitPattern: heap.count) == 5)
    }

    @Test("Min-heap ordering with inline storage")
    func minHeapOrderingInline() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 1)  // Min element at top
        #expect(heap.isSpilled == false)
    }

    @Test("Max-heap ordering with inline storage")
    func maxHeapOrderingInline() {
        var heap = Heap<Int>.Small<8>(order: .descending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 7)  // Max element at top
        #expect(heap.isSpilled == false)
    }

    @Test("Min-heap ordering after spill")
    func minHeapOrderingAfterSpill() {
        var heap = Heap<Int>.Small<2>(order: .ascending)
        heap.push(5)
        heap.push(3)
        #expect(heap.isSpilled == false)

        heap.push(7)
        heap.push(1)
        #expect(heap.isSpilled == true)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test("Pop in order (min-heap) inline")
    func popMinInOrderInline() throws {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop in order (max-heap) inline")
    func popMaxInOrderInline() throws {
        var heap = Heap<Int>.Small<8>(order: .descending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(try heap.pop() == 7)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop in order after spill")
    func popInOrderAfterSpill() throws {
        var heap = Heap<Int>.Small<2>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)
        #expect(heap.isSpilled == true)

        #expect(try heap.pop() == 1)
        #expect(try heap.pop() == 3)
        #expect(try heap.pop() == 5)
        #expect(try heap.pop() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() {
        typealias TestHeap = Heap<Int>.Small<8>
        
        var heap = TestHeap(order: .ascending)
        #expect(throws: TestHeap.Error.empty) {
            try heap.pop()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        #expect(heap.take == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
    }

    @Test("Clear after spill")
    func clearAfterSpill() {
        var heap = Heap<Int>.Small<2>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        #expect(heap.isSpilled == true)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(heap.isSpilled == false)  // removeAll() resets to inline mode
    }

    @Test("Heap grows after spill")
    func heapGrowsAfterSpill() {
        var heap = Heap<Int>.Small<2>(order: .ascending)

        // Fill inline
        heap.push(1)
        heap.push(2)

        // Spill and grow
        for i in 3...20 {
            heap.push(i)
        }

        #expect(Int(bitPattern: heap.count) == 20)
        #expect(heap.isSpilled == true)
        #expect(heap.peek == 1)  // Min at top
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
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
        var heap = Heap<Int>.Small<2>(order: .ascending)
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

    @Test("withPriority borrowing access")
    func withPriorityBorrowing() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test("Truncate reduces count inline")
    func truncateReducesCountInline() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)

        heap.truncate(to: 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("Truncate after spill")
    func truncateAfterSpill() {
        var heap = Heap<Int>.Small<2>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)
        #expect(heap.isSpilled == true)

        heap.truncate(to: 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("Capacity reflects storage type")
    func capacityReflectsStorageType() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        #expect(Int(bitPattern: heap.capacity) == 4)  // Inline capacity

        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)  // Spills

        #expect(heap.isSpilled == true)
        #expect(Int(bitPattern: heap.capacity) >= 5)  // Heap capacity
    }

    @Test("drain(while:) drains some elements in priority order")
    func drainWhileSome() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        for e in [5, 3, 8, 1, 4] { heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test("drain(while:) drains zero elements")
    func drainWhileNone() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        for e in [5, 3, 8] { heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test("drain(while:) drains all elements")
    func drainWhileAll() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        for e in [5, 3, 8, 1] { heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty == true)
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
        var heap = Heap<UniqueResource>.Small<8>(order: .ascending)

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))

        #expect(Int(bitPattern: heap.count) == 3)
        #expect(heap.isSpilled == false)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test("Push and access ~Copyable elements after spill")
    func pushAndAccessAfterSpill() {
        var heap = Heap<UniqueResource>.Small<2>(order: .ascending)

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))
        heap.push(UniqueResource(id: 1))

        #expect(Int(bitPattern: heap.count) == 4)
        #expect(heap.isSpilled == true)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 1)
    }

    @Test("forEach with ~Copyable elements")
    func forEachNonCopyable() {
        var heap = Heap<UniqueResource>.Small<8>(order: .ascending)
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
        var heap = Heap<UniqueResource>.Small<4>(order: .ascending)
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }

    @Test("Deinit properly cleans up ~Copyable elements after spill")
    func deinitCleansUpAfterSpill() {
        var heap = Heap<UniqueResource>.Small<2>(order: .ascending)
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        heap.push(UniqueResource(id: 4))
        #expect(heap.isSpilled == true)
        // heap goes out of scope - deinit should clean up properly
    }
}
