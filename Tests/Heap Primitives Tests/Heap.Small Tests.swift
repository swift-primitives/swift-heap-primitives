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

import Index_Primitives_Test_Support
import Testing

@testable import Heap_Primitives

@Suite("Heap.Small (Single-Ended)")
struct HeapSmallTests {
    @Test
    func `Init creates empty heap`() {
        let heap = Heap<Int>.Small<4>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
        #expect(heap.isSpilled == false)
    }

    @Test
    func `Push within inline capacity`() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)

        #expect(Int(bitPattern: heap.count) == 4)
        #expect(heap.isSpilled == false)
    }

    @Test
    func `Push spills to heap`() {
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

    @Test
    func `Min-heap ordering with inline storage`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 1)  // Min element at top
        #expect(heap.isSpilled == false)
    }

    @Test
    func `Max-heap ordering with inline storage`() {
        var heap = Heap<Int>.Small<8>(order: .descending)
        heap.push(5)
        heap.push(3)
        heap.push(7)
        heap.push(1)

        #expect(heap.peek == 7)  // Max element at top
        #expect(heap.isSpilled == false)
    }

    @Test
    func `Min-heap ordering after spill`() {
        var heap = Heap<Int>.Small<2>(order: .ascending)
        heap.push(5)
        heap.push(3)
        #expect(heap.isSpilled == false)

        heap.push(7)
        heap.push(1)
        #expect(heap.isSpilled == true)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test
    func `Pop in order (min-heap) inline`() throws {
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

    @Test
    func `Pop in order (max-heap) inline`() throws {
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

    @Test
    func `Pop in order after spill`() throws {
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

    @Test
    func `Pop throws when empty`() {
        typealias TestHeap = Heap<Int>.Small<8>

        var heap = TestHeap(order: .ascending)
        #expect(throws: TestHeap.Error.empty) {
            try heap.pop()
        }
    }

    @Test
    func `Take returns nil when empty`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        #expect(heap.take == nil)
    }

    @Test
    func `Clear removes all elements`() {
        var heap = Heap<Int>.Small<4>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
    }

    @Test
    func `Clear after spill`() {
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

    @Test
    func `Heap grows after spill`() {
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

    @Test
    func `forEach with borrowing access`() {
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

    @Test
    func `forEach after spill`() {
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

    @Test
    func `withPriority borrowing access`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(5)
        heap.push(3)
        heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test
    func `Truncate reduces count inline`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        heap.push(1)
        heap.push(2)
        heap.push(3)
        heap.push(4)
        heap.push(5)

        heap.truncate(to: 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `Truncate after spill`() {
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

    @Test
    func `Capacity reflects storage type`() {
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

    @Test
    func `drain(while:) drains some elements in priority order`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        for e in [5, 3, 8, 1, 4] { heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test
    func `drain(while:) drains zero elements`() {
        var heap = Heap<Int>.Small<8>(order: .ascending)
        for e in [5, 3, 8] { heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:) drains all elements`() {
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

    @Test
    func `Push and access ~Copyable elements inline`() {
        var heap = Heap<UniqueResource>.Small<8>(order: .ascending)

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))

        #expect(Int(bitPattern: heap.count) == 3)
        #expect(heap.isSpilled == false)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test
    func `Push and access ~Copyable elements after spill`() {
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

    @Test
    func `forEach with ~Copyable elements`() {
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

    @Test
    func `Deinit properly cleans up ~Copyable elements inline`() {
        var heap = Heap<UniqueResource>.Small<4>(order: .ascending)
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }

    @Test
    func `Deinit properly cleans up ~Copyable elements after spill`() {
        var heap = Heap<UniqueResource>.Small<2>(order: .ascending)
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))
        heap.push(UniqueResource(id: 4))
        #expect(heap.isSpilled == true)
        // heap goes out of scope - deinit should clean up properly
    }
}
