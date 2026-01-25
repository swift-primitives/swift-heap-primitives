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

public import Heap_Primitives_Core

// MARK: - Swift.Sequence Conformance
//
// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
// Separate module to avoid constraint poisoning on Core types.

extension Heap.Fixed: Swift.Sequence where Element: Copyable {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Heap<Element>.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        init(_storage: Heap<Element>.Storage) {
            self._storage = _storage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _storage.header else { return nil }
            defer { _index += 1 }
            return _storage._readElement(at: _index)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage: _storage)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count }
}
