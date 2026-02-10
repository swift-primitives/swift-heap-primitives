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

// MARK: - Heap.Fixed Tests (Single-Ended)

@Suite("Heap.Fixed (Single-Ended)")
struct HeapFixedTests {
    @Test("Init with capacity")
    func initWithCapacity() throws {
        let heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(heap.isEmpty == true)
        #expect(Int(heap.count.rawValue.rawValue) == 0)
        #expect(Int(heap.capacity.rawValue.rawValue) >= 10)
        #expect(heap.isFull == false)
    }

    @Test("Init with negative capacity throws")
    func initNegativeCapacityThrows() {
        #expect(throws: Heap<Int>.Fixed.Error.invalidCapacity) {
            _ = try Heap<Int>.Fixed(capacity: -1)
        }
    }

    @Test("Push returns inserted on success")
    func pushReturnsInserted() throws {
        var heap = try Heap<Int>.Fixed(capacity: 5, order: .ascending)
        let outcome = heap.push(42)
        switch outcome {
        case .inserted:
            break  // Expected
        case .overflow:
            Issue.record("Expected .inserted but got .overflow")
        }
        #expect(Int(heap.count.rawValue.rawValue) == 1)
    }

    @Test("Push returns overflow when full")
    func pushReturnsOverflowWhenFull() throws {
        // Buffer.Linear.Bounded allocates at least the requested capacity.
        // Fill the actual allocated capacity to test overflow.
        var heap = try Heap<Int>.Fixed(capacity: 2, order: .ascending)
        let actualCapacity = Int(heap.capacity.rawValue.rawValue)
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
        #expect(Int(heap.count.rawValue.rawValue) == actualCapacity)
    }

    @Test("Min-heap ordering (ascending)")
    func minHeapOrdering() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)
        _ = heap.push(9)

        #expect(heap.peek == 1)  // Min at top
    }

    @Test("Max-heap ordering (descending)")
    func maxHeapOrdering() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .descending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)
        _ = heap.push(1)
        _ = heap.push(9)

        #expect(heap.peek == 9)  // Max at top
    }

    @Test("Pop in order (min-heap)")
    func popMinInOrder() throws {
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

    @Test("Pop in order (max-heap)")
    func popMaxInOrder() throws {
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

    @Test("Pop throws when empty")
    func popThrowsWhenEmpty() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(throws: Heap<Int>.Fixed.Error.empty) {
            try heap.pop()
        }
    }

    @Test("Take returns nil when empty")
    func takeReturnsNilWhenEmpty() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        #expect(heap.take == nil)
    }

    @Test("Clear removes all elements")
    func clearRemovesAllElements() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(1)
        _ = heap.push(2)
        _ = heap.push(3)

        heap.remove.all()
        #expect(heap.isEmpty == true)
        #expect(Int(heap.count.rawValue.rawValue) == 0)
        #expect(Int(heap.capacity.rawValue.rawValue) >= 10)  // Capacity unchanged (at least requested)
    }

    @Test("Single element")
    func singleElement() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(42)

        #expect(heap.peek == 42)
        #expect(Int(heap.count.rawValue.rawValue) == 1)
    }

    @Test("Copy-on-write semantics")
    func copyOnWriteSemantics() throws {
        var heap1 = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap1.push(5)
        _ = heap1.push(3)

        let heap2 = heap1  // Copy

        _ = heap1.push(1)

        #expect(Int(heap1.count.rawValue.rawValue) == 3)
        #expect(Int(heap2.count.rawValue.rawValue) == 2)
        #expect(heap1.peek == 1)
        #expect(heap2.peek == 3)
    }

    @Test("Init from sequence")
    func initFromSequence() throws {
        let heap = try Heap<Int>.Fixed([5, 3, 7, 1, 9], capacity: 10, order: .ascending)
        #expect(Int(heap.count.rawValue.rawValue) == 5)
        #expect(heap.peek == 1)
    }

    @Test("Init from sequence truncates to capacity")
    func initFromSequenceTruncates() throws {
        let heap = try Heap<Int>.Fixed([1, 2, 3, 4, 5], capacity: 3, order: .ascending)
        #expect(Int(heap.count.rawValue.rawValue) == 3)
    }

    @Test("Sequence conformance")
    func sequenceConformance() throws {
        let heap = try Heap<Int>.Fixed([5, 3, 7, 1, 9], capacity: 10, order: .ascending)
        var elements: [Int] = []
        for element in heap {
            elements.append(element)
        }
        #expect(elements.count == 5)
        #expect(Set(elements) == Set([1, 3, 5, 7, 9]))
    }

    @Test("forEach with borrowing access")
    func forEachBorrowingAccess() throws {
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

    @Test("withPriority borrowing access")
    func withPriorityBorrowing() throws {
        var heap = try Heap<Int>.Fixed(capacity: 10, order: .ascending)
        _ = heap.push(5)
        _ = heap.push(3)
        _ = heap.push(7)

        let value = heap.withPriority { $0 * 2 }
        #expect(value == 6)  // 3 * 2 (min element)
    }

    @Test("Truncate reduces count")
    func truncateReducesCount() throws {
        var heap = try Heap<Int>.Fixed([1, 2, 3, 4, 5], capacity: 10, order: .ascending)
        #expect(Int(heap.count.rawValue.rawValue) == 5)

        heap.truncate(to: 3)
        #expect(Int(heap.count.rawValue.rawValue) == 3)
    }

    @Test("Zero capacity heap")
    func zeroCapacityHeap() throws {
        // Buffer.Linear.Bounded may allocate some minimum capacity even for 0.
        // Test that we can at least create one and it starts empty.
        let heap = try Heap<Int>.Fixed(capacity: 0, order: .ascending)
        #expect(heap.isEmpty == true)
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

    @Test("Push and access ~Copyable elements")
    func pushAndAccess() throws {
        var heap = try Heap<UniqueResource>.Fixed(capacity: 10, order: .ascending)

        _ = heap.push(UniqueResource(id: 10))
        _ = heap.push(UniqueResource(id: 5))
        _ = heap.push(UniqueResource(id: 15))

        #expect(Int(heap.count.rawValue.rawValue) == 3)

        let minId = heap.withPriority { $0.id }
        #expect(minId == 5)
    }

    @Test("Overflow preserves ~Copyable element")
    func overflowPreservesElement() throws {
        // Buffer.Linear.Bounded allocates at least the requested capacity.
        // Fill the actual allocated capacity to test overflow.
        var heap = try Heap<UniqueResource>.Fixed(capacity: 2, order: .ascending)
        let actualCapacity = Int(heap.capacity.rawValue.rawValue)
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

    @Test("forEach with ~Copyable elements")
    func forEachNonCopyable() throws {
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
