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


extension Heap.MinMax {
    /// Fixed-capacity min-max heap.
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Bounded

        /// Creates an empty fixed-capacity min-max heap.
        ///
        /// - Parameter capacity: Maximum number of elements.
        /// - Throws: Error if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(Heap.Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._buffer = Buffer<Element>.Linear.Bounded(
                minimumCapacity: Heap.Index.Count(__unchecked: (), Cardinal(UInt(capacity)))
            )
        }
    }
}
