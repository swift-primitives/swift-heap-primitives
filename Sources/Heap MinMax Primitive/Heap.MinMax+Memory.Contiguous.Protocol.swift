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

public import Heap_Primitive
public import Buffer_Linear_Primitive
public import Memory_Contiguous_Primitives

// MARK: - Memory.Contiguous.Protocol Conformance
//
// Co-located with the type and its span witness ([MOD-036] refined-C). The
// memory→Iterable bridge keys off this conformance to vend the borrowing
// `Iterator.Chunk` when the type also declares `: Iterable` (ops module).
// Elements are in min-max heap order, NOT sorted order.

extension Heap.MinMax: Memory.Contiguous.`Protocol` where Element: ~Copyable {
    /// A read-only view of the heap's elements in min-max heap order.
    /// Witness for `Memory.Contiguous.Protocol`.
    @inlinable
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get { _buffer.span }
    }
}
