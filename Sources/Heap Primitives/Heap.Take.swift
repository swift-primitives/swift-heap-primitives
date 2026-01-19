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

// MARK: - Take Accessor

extension Heap {
    /// Nested accessor for optional removal operations.
    ///
    /// Use `take` when empty is a normal state (priority queue drain):
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// while let min = heap.take.min {
    ///     process(min)
    /// }
    /// ```
    ///
    /// Use `pop` when empty is exceptional and should throw.
    @inlinable
    public var take: Take {
        _read {
            yield Take(storage: storage)
        }
        _modify {
            var proxy = Take(storage: storage)
            storage = Storage()
            defer { storage = proxy.storage }
            yield &proxy
        }
    }
}

// MARK: - Take Type

extension Heap {
    /// Namespace for optional removal operations.
    public struct Take {
        @usableFromInline
        var storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Take Operations

extension Heap.Take {
    /// Removes and returns the minimum element, or `nil` if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var min: Element? {
        mutating get {
            storage.removeMin()
        }
    }

    /// Removes and returns the maximum element, or `nil` if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var max: Element? {
        mutating get {
            storage.removeMax()
        }
    }
}
