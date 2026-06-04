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
import Storage_Heap_Primitives
public import Buffer_Linear_Inline_Primitives

// MARK: - Sequenceable witness (makeIterator)
//
// The single-pass consuming iterator in heap order — the `Copyable` witness for
// the cold `Sequenceable` conformance (declared in the ops module). A public
// member in the type module per [MOD-036] refined-C; delegates to the composed
// buffer's public makeIterator. Enabled by `@frozen` on the Static struct, which
// permits the partial consume of `_buffer`. Heap order is NOT sorted order.

extension Heap.Static where Element: Copyable {

    /// A single-pass consuming iterator in heap order. Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Heap>.Linear.Inline<capacity>.Scalar {
        _buffer.makeIterator()
    }
}
