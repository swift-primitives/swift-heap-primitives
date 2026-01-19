// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Replace Accessor

extension Heap {
    /// Nested accessor for replace operations.
    ///
    /// Replace is more efficient than pop + push when you need to
    /// replace the extremum:
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// let oldMin = try heap.replace.min(with: 0)  // returns 1, heap now has 0
    /// let oldMax = try heap.replace.max(with: 9)  // returns 5, heap now has 9
    /// ```
    @inlinable
    public var replace: Replace {
        _read {
            yield Replace(storage: storage)
        }
        _modify {
            var proxy = Replace(storage: storage)
            storage = Storage()
            defer { storage = proxy.storage }
            yield &proxy
        }
    }
}

// MARK: - Replace Type

extension Heap {
    /// Namespace for replace operations.
    public struct Replace {
        @usableFromInline
        var storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Replace Operations

extension Heap.Replace {
    /// Replaces the minimum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !storage.isEmpty else {
            throw .empty(.init())
        }
        return storage.replaceMin(with: replacement)
    }

    /// Replaces the maximum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original maximum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !storage.isEmpty else {
            throw .empty(.init())
        }
        return storage.replaceMax(with: replacement)
    }
}
