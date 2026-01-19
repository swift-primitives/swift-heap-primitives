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

// MARK: - Pop Accessor

extension Heap {
    /// Nested accessor for pop operations.
    ///
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// let min = try heap.pop.min()  // 1
    /// let max = try heap.pop.max()  // 5
    /// ```
    @inlinable
    public var pop: Pop {
        _read {
            yield Pop(storage: storage)
        }
        _modify {
            var proxy = Pop(storage: storage)
            storage = Storage()
            defer { storage = proxy.storage }
            yield &proxy
        }
    }
}

// MARK: - Pop Type

extension Heap {
    /// Namespace for pop operations.
    public struct Pop {
        @usableFromInline
        var storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Pop Operations

extension Heap.Pop {
    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min() throws(Heap<Element>.Error) -> Element {
        guard let element = storage.removeMin() else {
            throw .empty(.init())
        }
        return element
    }

    /// Removes and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max() throws(Heap<Element>.Error) -> Element {
        guard let element = storage.removeMax() else {
            throw .empty(.init())
        }
        return element
    }
}
