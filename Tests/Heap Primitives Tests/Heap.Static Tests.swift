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

// MARK: - Heap.Static Tests (Single-Ended)

@Suite("Heap.Static (Single-Ended)")
struct HeapStaticTests {
    @Test
    func `Init creates empty heap`() {
        let heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
        #expect(heap.isFull == false)
    }

    @Test
    func `Push returns inserted on success`() {
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

    @Test
    func `Push returns overflow when full`() {
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

    @Test
    func `Min-heap ordering (ascending)`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test
    func `Max-heap ordering (descending)`() {
        var heap = Heap<Int>.Static<8>(order: .descending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)

        #expect(heap.peek == 7)  // Max at top
    }

    @Test
    func `Pop in order (min-heap)`() throws {
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

    @Test
    func `Pop in order (max-heap)`() throws {
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

    @Test
    func `Pop throws when empty`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(throws: Heap<Int>.Static<8>.Error.empty) {
            try heap.pop()
        }
    }

    @Test
    func `Take returns nil when empty`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        #expect(heap.take == nil)
    }

    @Test
    func `Clear removes all elements`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(bitPattern: heap.count) == 0)
    }

    @Test
    func `Single element`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(42)

        #expect(heap.peek == 42)
        #expect(Int(bitPattern: heap.count) == 1)
    }

    @Test
    func `Fill to capacity`() {
        var heap = Heap<Int>.Static<4>(order: .ascending)
        _ = heap.push(4)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(1)

        #expect(heap.isFull == true)
        #expect(Int(bitPattern: heap.count) == 4)
        #expect(heap.peek == 1)  // Min at top
    }

    @Test
    func `forEach with borrowing access`() {
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

    @Test
    func `withPriority borrowing access`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test
    func `Truncate reduces count`() {
        var heap = Heap<Int>.Static<8>(order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)
        _ = heap.push(4)
        _ = heap.push(5)

        heap.truncate(to: 3)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `Large capacity heap`() {
        var heap = Heap<Int>.Static<16>(order: .ascending)
        for i in 0..<16 {
            _ = heap.push(i)
        }
        #expect(heap.isFull == true)
        #expect(heap.peek == 0)  // Min at top
    }

    @Test
    func `drain(while:) drains some elements in priority order`() {
        var heap = Heap<Int>.Static<16>(order: .ascending)
        for e in [5, 3, 8, 1, 4] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test
    func `drain(while:) drains zero elements`() {
        var heap = Heap<Int>.Static<16>(order: .ascending)
        for e in [5, 3, 8] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:) drains all elements`() {
        var heap = Heap<Int>.Static<16>(order: .ascending)
        for e in [5, 3, 8, 1] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty == true)
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

    @Test
    func `Push and access ~Copyable elements`() {
        var heap = Heap<UniqueResource>.Static<8>(order: .ascending)

        _ = heap.push(UniqueResource(id: 10))
        _ = heap.push(UniqueResource(id: 5))
        _ = heap.push(UniqueResource(id: 15))

        #expect(Int(bitPattern: heap.count) == 3)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test
    func `Overflow preserves ~Copyable element`() {
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

    @Test
    func `forEach with ~Copyable elements`() {
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

    @Test
    func `Deinit properly cleans up ~Copyable elements`() {
        // This test ensures no crash on deallocation
        var heap = Heap<UniqueResource>.Static<4>(order: .ascending)
        _ = heap.push(UniqueResource(id: 1))
        _ = heap.push(UniqueResource(id: 2))
        _ = heap.push(UniqueResource(id: 3))
        // heap goes out of scope - deinit should clean up properly
    }
}

// Note: Tests for Heap.MinMax.Static will be added when that variant is fully implemented.
