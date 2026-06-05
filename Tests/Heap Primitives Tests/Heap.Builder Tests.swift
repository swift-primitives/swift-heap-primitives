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

// MARK: - Test Suite Structure

@Suite("Heap.Builder")
struct HeapBuilderTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite struct OrderParameter {}
    @Suite struct StaticMethods {}
}

// MARK: - Iteration Helper (drain via repeated pop)

extension HeapBuilderTests {
    fileprivate static func drainPopOrder(
        _ heap: consuming Heap<Int>
    ) throws -> [Int] {
        var rest = consume heap
        var result: [Int] = []
        while !rest.isEmpty {
            result.append(try rest.pop())
        }
        return result
    }
}

// MARK: - Order Parameter (OQ4=A verification)

extension HeapBuilderTests.OrderParameter {

    @Test
    func `Default order is ascending - min heap`() throws {
        let heap = Heap<Int> {
            5
            1
            3
            2
            4
        }
        // pop yields ascending order
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 3, 4, 5])
    }

    @Test
    func `Ascending order explicit - min heap`() throws {
        let heap = Heap<Int>(order: .ascending) {
            5
            1
            3
            2
            4
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 3, 4, 5])
    }

    @Test
    func `Descending order - max heap`() throws {
        let heap = Heap<Int>(order: .descending) {
            5
            1
            3
            2
            4
        }
        // pop yields descending order
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [5, 4, 3, 2, 1])
    }

    @Test
    func `Min heap peek returns smallest`() {
        let heap = Heap<Int> {
            10
            5
            7
            3
        }
        #expect(heap.peek == 3)
    }

    @Test
    func `Max heap peek returns largest`() {
        let heap = Heap<Int>(order: .descending) {
            10
            5
            7
            3
        }
        #expect(heap.peek == 10)
    }
}

// MARK: - Unit Tests

extension HeapBuilderTests.Unit {

    @Test
    func `Single element expression`() throws {
        let heap = Heap<Int> { 42 }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [42])
    }

    @Test
    func `Multiple element expressions heapify correctly`() throws {
        let heap = Heap<Int> {
            3
            1
            2
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 3])
    }

    @Test
    func `Optional element - some`() throws {
        let value: Int? = 42
        let heap = Heap<Int> { value }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [42])
    }

    @Test
    func `Optional element - none`() {
        let value: Int? = nil
        let heap = Heap<Int> { value }
        let isEmpty = heap.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `Mixed elements and optionals heapify`() throws {
        let some: Int? = 2
        let none: Int? = nil
        let heap = Heap<Int> {
            5
            some
            none
            1
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 5])
    }

    @Test
    func `Empty block`() {
        let heap = Heap<Int> {}
        let isEmpty = heap.isEmpty
        #expect(isEmpty)
    }
}

// MARK: - Control Flow

extension HeapBuilderTests.Unit {

    @Test
    func `Conditional include affects heap contents`() throws {
        let include = true
        let heap = Heap<Int> {
            5
            if include {
                1
            }
            3
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 3, 5])
    }

    @Test
    func `Conditional exclude affects heap contents`() throws {
        let include = false
        let heap = Heap<Int> {
            5
            if include {
                1
            }
            3
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [3, 5])
    }

    @Test
    func `If-else first branch`() throws {
        let condition = true
        let heap = Heap<Int> {
            if condition {
                10
            } else {
                20
            }
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [10])
    }

    @Test
    func `If-else second branch`() throws {
        let condition = false
        let heap = Heap<Int> {
            if condition {
                10
            } else {
                20
            }
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [20])
    }
}

// MARK: - Edge Cases

extension HeapBuilderTests.EdgeCase {

    @Test
    func `Already-sorted ascending input`() throws {
        let heap = Heap<Int> {
            1
            2
            3
            4
            5
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 3, 4, 5])
    }

    @Test
    func `Reverse-sorted input`() throws {
        let heap = Heap<Int> {
            5
            4
            3
            2
            1
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 2, 3, 4, 5])
    }

    @Test
    func `Duplicates handled correctly`() throws {
        let heap = Heap<Int> {
            3
            1
            3
            1
            2
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 1, 2, 3, 3])
    }

    @Test
    func `Many elements heapify`() throws {
        let heap = Heap<Int> {
            10
            5
            8
            1
            3
            7
            2
            9
            4
            6
        }
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == Swift.Array(1...10))
    }
}

// MARK: - Integration

extension HeapBuilderTests.Integration {

    @Test
    func `Builder result accepts further pushes`() throws {
        var heap = Heap<Int> {
            5
            10
            3
        }
        heap.push(1)
        heap.push(8)
        let popped = try HeapBuilderTests.drainPopOrder(heap)
        #expect(popped == [1, 3, 5, 8, 10])
    }
}

// MARK: - Static Method Tests

extension HeapBuilderTests.StaticMethods {

    @Test
    func `buildExpression single element`() {
        var result = Heap<Int>.Builder.buildExpression(42)
        // Result is a Buffer<Storage<Int>.Contiguous<Memory.Heap<Int>>>.Linear (intermediate type)
        #expect(!result.isEmpty)
        #expect(result.remove.first() == 42)
    }

    @Test
    func `buildBlock empty`() {
        let result = Heap<Int>.Builder.buildBlock()
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildOptional none returns empty buffer`() {
        let component: Buffer<Storage<Int>.Contiguous<Memory.Heap<Int>>>.Linear? = nil
        let result = Heap<Int>.Builder.buildOptional(component)
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }

    @Test
    func `buildPartialBlock first void returns empty buffer`() {
        let result = Heap<Int>.Builder.buildPartialBlock(first: ())
        let isEmpty = result.isEmpty
        #expect(isEmpty)
    }
}
