// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Take Accessor (Copyable elements only)

extension Heap where Element: Copyable {
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
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var take: Take {
        _read {
            yield Take(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Take(heap: self)
            self = Heap()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Take Type

extension Heap where Element: Copyable {
    /// Namespace for optional removal operations.
    public struct Take {
        @usableFromInline
        var heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Take Operations

extension Heap.Take where Element: Copyable {
    /// Removes and returns the minimum element, or `nil` if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var min: Element? {
        mutating get {
            heap._removeMin()
        }
    }

    /// Removes and returns the maximum element, or `nil` if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var max: Element? {
        mutating get {
            heap._removeMax()
        }
    }
}
