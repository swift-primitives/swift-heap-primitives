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

// MARK: - Heap.Fixed Tests (Single-Ended)

@Suite("Heap.Fixed (Single-Ended)")
struct HeapFixedTests {
    @Test
    func `Init with capacity`() throws {
        let heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(heap.count.underlying.rawValue) == 0)
        #expect(Int(heap.capacity.underlying.rawValue) >= 10)
        #expect(heap.isFull == false)
    }

    @Test
    func `Init with negative capacity throws`() {
        #expect(throws: Heap<Int>.Fixed.Error.invalidCapacity) {
            _ = try Heap<Int>.Fixed(capacity: -1)
        }
    }

    @Test
    func `Push returns inserted on success`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 5, order: .ascending)
        let outcome = heap.push(42)
        switch outcome {
        case .inserted:
            break  // Expected
        case .overflow:
            Issue.record("Expected .inserted but got .overflow")
        }
        #expect(Int(heap.count.underlying.rawValue) == 1)
    }

    @Test
    func `Push returns overflow when full`() throws {
        // Buffer.Linear.Bounded allocates at least the requested capacity.
        // Fill the actual allocated capacity to test overflow.
        var heap = try Heap<Int>.Fixed(capacity: 2, order: .ascending)
        let actualCapacity = Int(heap.capacity.underlying.rawValue)
        for i in 0..<actualCapacity {
            _ = heap.push(i)
        }
        #expect(heap.isFull == true)

        let outcome = heap.push(999)
        switch outcome {
        case .inserted:
            Issue.record("Expected .overflow but got .inserted")
        case .overflow(let element):
            #expect(element == 999)  // Element preserved
        }
        #expect(Int(heap.count.underlying.rawValue) == actualCapacity)
    }

    @Test
    func `Min-heap ordering (ascending)`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)
        _ = heap.push(9)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test
    func `Max-heap ordering (descending)`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .descending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)
        _ = heap.push(9)

        #expect(heap.peek == 9)  // Max at top
    }

    @Test
    func `Pop in order (min-heap)`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
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
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .descending)
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
    func `Pop throws when empty`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(throws: Heap<Int>.Fixed.Error.empty) {
            try heap.pop()
        }
    }

    @Test
    func `Take returns nil when empty`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(heap.take == nil)
    }

    @Test
    func `Clear removes all elements`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(heap.count.underlying.rawValue) == 0)
        #expect(Int(heap.capacity.underlying.rawValue) >= 10)  // Capacity unchanged (at least requested)
    }

    @Test
    func `Single element`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(42)

        #expect(heap.peek == 42)
        #expect(Int(heap.count.underlying.rawValue) == 1)
    }

    @Test
    func `Copy-on-write semantics`() throws {
        var heap1 = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap1.push(5)
        _ = heap1.push(3)

        let heap2 = heap1  // Copy

        _ = heap1.push(1)

        #expect(Int(heap1.count.underlying.rawValue) == 3)
        #expect(Int(heap2.count.underlying.rawValue) == 2)
        #expect(heap1.peek == 1)
        #expect(heap2.peek == 3)
    }

    @Test
    func `Copies share storage until mutation, and the CoW detach preserves capacity`() throws {
        var a = try Heap<Int>.Fixed(capacity: 4, order: .ascending)
        _ = a.push(2)
        _ = a.push(1)

        // Copy shares the box; the first mutation of `b` detaches through the
        // CAPACITY-PRESERVING clone (a shrink-to-fit copy would make the
        // in-contract pushes below overflow).
        var b = a
        _ = b.push(3)
        #expect(Int(bitPattern: a.count) == 2)  // a untouched by b's mutation
        #expect(Int(bitPattern: b.count) == 3)
        #expect(Int(bitPattern: b.capacity) == 4)

        let outcome = b.push(4)  // still in-contract after the detach
        switch outcome {
        case .inserted:
            break  // Expected
        case .overflow:
            Issue.record("Expected .inserted but got .overflow")
        }
        #expect(b.isFull == true)
        #expect(a.peek == 1)
        #expect(b.peek == 1)
    }

    @Test
    func `Init from sequence`() throws {
        let heap = try Heap<Int>.Fixed([5, 3, 7, 1, 9], capacity: 10, order: .ascending)
        #expect(Int(heap.count.underlying.rawValue) == 5)
        #expect(heap.peek == 1)
    }

    @Test
    func `Init from sequence truncates to capacity`() throws {
        let heap = try Heap<Int>.Fixed([1, 2, 3, 4, 5], capacity: 3, order: .ascending)
        #expect(Int(heap.count.underlying.rawValue) == 3)
    }

    @Test
    func `forEach traverses all elements`() throws {
        let heap = try Heap<Int>.Fixed([5, 3, 7, 1, 9], capacity: 10, order: .ascending)
        var elements: [Int] = []
        // The `Iterable` lattice membership is withdrawn at the A-1 reshape
        // (the stored Shared column has no returning span); `forEach` survives
        // as a plain member over the column's scoped borrowing access.
        heap.forEach { element in
            elements.append(element)
        }
        #expect(elements.count == 5)
        #expect(Set(elements) == Set([1, 3, 5, 7, 9]))
    }

    @Test
    func `forEach with borrowing access`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
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
    func `withPriority borrowing access`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test
    func `Truncate reduces count`() throws {
        var heap = try Heap<Int>.Fixed([1, 2, 3, 4, 5], capacity: 10, order: .ascending)
        #expect(Int(heap.count.underlying.rawValue) == 5)

        heap.truncate(to: 3)
        #expect(Int(heap.count.underlying.rawValue) == 3)
    }

    @Test
    func `Zero capacity heap`() throws {
        // Buffer.Linear.Bounded may allocate some minimum capacity even for 0.
        // Test that we can at least create one and it starts empty.
        let heap = try Heap<Int>.Fixed(capacity: 0, order: .ascending)
        #expect(heap.isEmpty == true)
    }

    @Test
    func `drain(while:) drains some elements in priority order`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        for e in [5, 3, 8, 1, 4] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 < 5 }) { drained.append($0) }
        #expect(drained == [1, 3, 4])
        #expect(Int(bitPattern: heap.count) == 2)
    }

    @Test
    func `drain(while:) drains zero elements`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        for e in [5, 3, 8] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { $0 > 100 }) { drained.append($0) }
        #expect(drained.isEmpty)
        #expect(Int(bitPattern: heap.count) == 3)
    }

    @Test
    func `drain(while:) drains all elements`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        for e in [5, 3, 8, 1] { _ = heap.push(e) }
        var drained: [Int] = []
        heap.drain(while: { _ in true }) { drained.append($0) }
        #expect(drained == [1, 3, 5, 8])
        #expect(heap.isEmpty)
    }
}

// MARK: - ~Copyable Element Tests

@Suite("Heap.Fixed with ~Copyable elements")
struct HeapFixedNonCopyableTests {
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
    func `Push and access ~Copyable elements`() throws {
        var heap = try Heap<UniqueResource>.Fixed(capacity: 10, order: .ascending)

        _ = heap.push(UniqueResource(id: 10))
        _ = heap.push(UniqueResource(id: 5))
        _ = heap.push(UniqueResource(id: 15))

        #expect(Int(heap.count.underlying.rawValue) == 3)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test
    func `Overflow preserves ~Copyable element`() throws {
        // Buffer.Linear.Bounded allocates at least the requested capacity.
        // Fill the actual allocated capacity to test overflow.
        var heap = try Heap<UniqueResource>.Fixed(capacity: 2, order: .ascending)
        let actualCapacity = Int(heap.capacity.underlying.rawValue)
        for i in 0..<actualCapacity {
            _ = heap.push(UniqueResource(id: i))
        }

        let outcome = heap.push(UniqueResource(id: 999))
        switch outcome {
        case .overflow(let resource):
            #expect(resource.id == 999)  // Element preserved
        case .inserted:
            Issue.record("Expected overflow")
        }
    }

    @Test
    func `forEach with ~Copyable elements`() throws {
        var heap = try Heap<UniqueResource>.Fixed(capacity: 10, order: .ascending)
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

// Note: Tests for Heap.MinMax.Fixed will be added when that variant is fully implemented.
