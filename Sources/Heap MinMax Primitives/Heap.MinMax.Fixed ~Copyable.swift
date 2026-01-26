//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

public import Pointer_Primitives

extension Heap.MinMax {
    /// Fixed-capacity min-max heap.
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        var _storage: Heap.Storage

        public let capacity: Int

        @usableFromInline
        package var _cachedPtr: Heap.Pointer.Mutable

        /// Creates an empty fixed-capacity min-max heap.
        ///
        /// - Parameter capacity: Maximum number of elements.
        /// - Throws: Error if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(Heap.Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._storage = Heap.Storage.create(minimumCapacity: capacity)
            self.capacity = capacity
            self._cachedPtr = _storage._elementsPointer
        }
    }
}
