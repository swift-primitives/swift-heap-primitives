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

import Buffer_Linear_Primitive
import Buffer_Primitive
import Buffer_Primitives_Test_Support
import Heap_Primitives
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Storage_Primitive
import Testing

// MARK: - [DS-024] Seam.Ledger law — per front-door column

// The canonical `Heap<E>` front door pins exactly one column: the direct, heap-
// allocated contiguous linear buffer. [DS-024] requires every column consumed as an
// ADT storage column to keep `count` honest through its seam ops (initialize +1,
// move -1, subscript unchanged, capacity untouched) and to PROVE it by running
// `Seam.Ledger.violations` from its own suite (the type system cannot express the
// contract the seam-generic sift/pop machinery relies on).

private typealias HeapColumn<E: ~Copyable> =
    Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear

@Suite("Heap seam laws")
struct HeapSeamTests {

    @Test("[DS-024] Seam.Ledger laws hold for the canonical Heap column")
    func canonicalColumnLedgerLaws() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { HeapColumn<Int>(minimumCapacity: Index<Int>.Count(4)) },
            element: { $0 }
        )
        #expect(violations.isEmpty, "\(violations)")
    }
}
