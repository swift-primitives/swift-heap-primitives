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

@Suite("Heap.Binary")
struct HeapBinaryTests {
    @Test("Min-max heap provides both min and max")
    func minMaxHeapOrdering() throws {
        var heap: Heap<Int>.Binary = [5, 3, 7, 1, 9]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 9)

        #expect(try heap.pop.min() == 1)
        #expect(try heap.pop.max() == 9)
        #expect(heap.peek.min == 3)
        #expect(heap.peek.max == 7)
    }

    @Test("Pop min in order")
    func popMinInOrder() throws {
        var heap: Heap<Int>.Binary = [5, 3, 7, 1]

        #expect(try heap.pop.min() == 1)
        #expect(try heap.pop.min() == 3)
        #expect(try heap.pop.min() == 5)
        #expect(try heap.pop.min() == 7)
        #expect(heap.isEmpty == true)
    }

    @Test("Pop max in order")
    func popMaxInOrder() throws {
        var heap: Heap<Int>.Binary = [5, 3, 7, 1]

        #expect(try heap.pop.max() == 7)
        #expect(try heap.pop.max() == 5)
        #expect(try heap.pop.max() == 3)
        #expect(try heap.pop.max() == 1)
        #expect(heap.isEmpty == true)
    }

    @Test("Peek does not remove")
    func peekDoesNotRemove() {
        let heap: Heap<Int>.Binary = [3, 1, 2]

        #expect(heap.peek.min == 1)
        #expect(heap.peek.min == 1)
        #expect(heap.peek.max == 3)
        #expect(heap.peek.max == 3)
        #expect(heap.count == 3)
    }

    @Test("Empty heap")
    func emptyHeap() {
        var heap = Heap<Int>.Binary()
        #expect(heap.isEmpty == true)
        #expect(heap.peek.min == nil)
        #expect(heap.peek.max == nil)
        #expect(heap.take.min == nil)
        #expect(heap.take.max == nil)
    }

    @Test("Single element")
    func singleElement() throws {
        var heap: Heap<Int>.Binary = [42]
        #expect(heap.isEmpty == false)
        #expect(heap.count == 1)
        #expect(heap.peek.min == 42)
        #expect(heap.peek.max == 42)
        #expect(try heap.pop.min() == 42)
        #expect(heap.isEmpty == true)
    }

    @Test("Remove all")
    func removeAll() {
        var heap: Heap<Int>.Binary = [1, 2, 3]
        #expect(heap.count == 3)

        heap.removeAll()
        #expect(heap.isEmpty == true)
    }

    @Test("Duplicate elements")
    func duplicateElements() {
        var heap: Heap<Int>.Binary = [5, 5, 5]

        #expect(heap.take.min == 5)
        #expect(heap.take.min == 5)
        #expect(heap.take.min == 5)
        #expect(heap.take.min == nil)
    }

    @Test("Push elements")
    func pushElements() {
        var heap = Heap<Int>.Binary()
        heap.push(5)
        heap.push(3)
        heap.push(7)

        #expect(heap.count == 3)
        #expect(heap.peek.min == 3)
        #expect(heap.peek.max == 7)
    }

    @Test("Take returns nil when empty")
    func takeReturnsNil() {
        var heap = Heap<Int>.Binary()
        #expect(heap.take.min == nil)
        #expect(heap.take.max == nil)
    }

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() {
        var heap = Heap<Int>.Binary()
        #expect(throws: Heap<Int>.Binary.Error.self) {
            try heap.pop.min()
        }
        #expect(throws: Heap<Int>.Binary.Error.self) {
            try heap.pop.max()
        }
    }

    @Test("Copy-on-write semantics")
    func copyOnWrite() {
        var heap1: Heap<Int>.Binary = [5, 3, 7]
        let heap2 = heap1

        heap1.push(1)

        #expect(heap1.count == 4)
        #expect(heap2.count == 3)
        #expect(heap1.peek.min == 1)
        #expect(heap2.peek.min == 3)
    }
}

// MARK: - ~Copyable Element Tests

/// A move-only resource for testing ~Copyable heap functionality.
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

@Suite("Heap.Binary with ~Copyable elements")
struct HeapBinaryNonCopyableTests {
    @Test("Push and access ~Copyable elements")
    func pushAndAccess() {
        var heap = Heap<UniqueResource>.Binary()

        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 15))

        let count = heap.count
        #expect(count == 3)

        // Access via borrowing closure
        let minId = heap.withMin { $0.id }
        #expect(minId == 5)

        let maxId = heap.withMax { $0.id }
        #expect(maxId == 15)
    }

    @Test("forEach with ~Copyable elements")
    func forEachAccess() {
        var heap = Heap<UniqueResource>.Binary()
        heap.push(UniqueResource(id: 3))
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))

        var ids: [Int] = []
        heap.forEach { element in
            ids.append(element.id)
        }

        #expect(ids.count == 3)
        #expect(ids.contains(1))
        #expect(ids.contains(2))
        #expect(ids.contains(3))
    }

    @Test("Empty ~Copyable heap")
    func emptyNonCopyableHeap() {
        let heap = Heap<UniqueResource>.Binary()

        let isEmpty = heap.isEmpty
        let count = heap.count
        #expect(isEmpty)
        #expect(count == 0)

        let minResult = heap.withMin { $0.id }
        #expect(minResult == nil)

        let maxResult = heap.withMax { $0.id }
        #expect(maxResult == nil)
    }

    @Test("Single ~Copyable element")
    func singleNonCopyableElement() {
        var heap = Heap<UniqueResource>.Binary()
        heap.push(UniqueResource(id: 42))

        let count = heap.count
        #expect(count == 1)

        // For single element, min == max
        let minId = heap.withMin { $0.id }
        let maxId = heap.withMax { $0.id }
        #expect(minId == 42)
        #expect(maxId == 42)
    }

    @Test("Remove all ~Copyable elements")
    func removeAllNonCopyable() {
        var heap = Heap<UniqueResource>.Binary()
        heap.push(UniqueResource(id: 1))
        heap.push(UniqueResource(id: 2))
        heap.push(UniqueResource(id: 3))

        var count = heap.count
        #expect(count == 3)

        heap.removeAll()

        let isEmpty = heap.isEmpty
        count = heap.count
        #expect(isEmpty)
        #expect(count == 0)
    }

    @Test("Heap ordering with ~Copyable elements")
    func heapOrderingNonCopyable() {
        var heap = Heap<UniqueResource>.Binary()

        // Push in non-sorted order
        heap.push(UniqueResource(id: 50))
        heap.push(UniqueResource(id: 10))
        heap.push(UniqueResource(id: 30))
        heap.push(UniqueResource(id: 5))
        heap.push(UniqueResource(id: 100))

        // Min should be 5, max should be 100
        let minId = heap.withMin { $0.id }
        let maxId = heap.withMax { $0.id }

        #expect(minId == 5)
        #expect(maxId == 100)
    }
}
