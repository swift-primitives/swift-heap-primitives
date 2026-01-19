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

// MARK: - Push Accessor

extension Heap {
    /// Nested accessor for push operations.
    ///
    /// ```swift
    /// var heap = Heap<Int>()
    /// heap.push(42)                    // single element
    /// heap.push.contentsOf([1, 2, 3])  // bulk insert
    /// ```
    @inlinable
    public var push: Push {
        _read {
            yield Push(storage: storage)
        }
        _modify {
            var proxy = Push(storage: storage)
            storage = Storage()
            defer { storage = proxy.storage }
            yield &proxy
        }
    }
}

// MARK: - Push Type

extension Heap {
    /// Namespace for push operations.
    public struct Push {
        @usableFromInline
        var storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Push Operations

extension Heap.Push {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func callAsFunction(_ element: Element) {
        storage.insert(element)
    }

    /// Inserts multiple elements into the heap.
    ///
    /// Uses a heuristic to choose between per-element insertion
    /// and full re-heapification for optimal performance.
    ///
    /// - Parameter elements: The elements to insert.
    /// - Complexity: O(n + k) where k is the number of new elements.
    @inlinable
    public mutating func contentsOf(_ elements: some Sequence<Element>) {
        storage.insert(contentsOf: elements)
    }
}
