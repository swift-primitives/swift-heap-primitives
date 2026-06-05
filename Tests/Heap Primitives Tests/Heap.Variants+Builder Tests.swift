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

@Suite("Heap variants + Builder")
struct HeapVariantsBuilderTests {
    @Suite struct FixedHeap {}
}

extension HeapVariantsBuilderTests.FixedHeap {
    @Test
    func `Fixed within capacity`() throws {
        var heap = try Heap<Int>.Fixed(capacity: 8) { 5; 1; 3 }
        #expect(heap.peek == 1)
    }

    @Test
    func `Fixed throws on overflow`() {
        do {
            _ = try Heap<Int>.Fixed(capacity: 1) { 1; 2; 3; 4; 5 }
            Issue.record("expected throw")
        } catch let e {
            #expect(e == .overflow)
        }
    }
}
