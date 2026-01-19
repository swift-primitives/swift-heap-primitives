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

// MARK: - Peek Accessor

extension Heap {
    /// Nested accessor for peek operations.
    ///
    /// ```swift
    /// let heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// if let min = heap.peek.min { print(min) }  // 1
    /// if let max = heap.peek.max { print(max) }  // 5
    /// ```
    @inlinable
    public var peek: Peek {
        Peek(storage: storage)
    }
}

// MARK: - Peek Type

extension Heap {
    /// Namespace for peek operations.
    public struct Peek {
        @usableFromInline
        let storage: Storage

        @usableFromInline
        init(storage: Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Peek Operations

extension Heap.Peek {
    /// The minimum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        storage.peekMin()
    }

    /// The maximum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        storage.peekMax()
    }
}
