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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
import Storage_Contiguous_Primitives
public import Buffer_Linear_Bounded_Primitive
import Index_Primitives

extension Heap.MinMax {
    /// Fixed-capacity min-max heap.
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Bounded

        /// Creates an empty fixed-capacity min-max heap.
        ///
        /// - Parameter capacity: Maximum number of elements.
        /// - Throws: Error if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(Heap.Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Bounded(
                minimumCapacity: Heap.Index.Count(_unchecked: Cardinal(UInt(capacity)))
            )
        }
    }
}
