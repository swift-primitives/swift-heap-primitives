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
public import Storage_Small_Primitives
public import Storage_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
import Storage_Heap_Primitives
public import Buffer_Linear_Small_Primitives

// MARK: - Sequenceable witness (makeIterator)
//
// The single-pass consuming iterator in heap order — the `Copyable` witness for
// the cold `Sequenceable` conformance (declared in the ops module). A public
// member in the type module per [MOD-036] refined-C; delegates to the composed
// buffer's public makeIterator. Enabled by `@frozen` on the Small struct, which
// permits the partial consume of `_buffer`. Heap order is NOT sorted order.

extension Heap.Small where Element: Copyable {

    /// A single-pass consuming iterator in heap order. Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Small<inlineCapacity>>.Linear.Scalar {
        _buffer.makeIterator()
    }
}
