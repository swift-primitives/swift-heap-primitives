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

// MARK: - Pop Accessor (Copyable elements only)

extension Heap where Element: Copyable {
    /// Nested accessor for pop operations.
    ///
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// let min = try heap.pop.min()  // 1
    /// let max = try heap.pop.max()  // 5
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var pop: Pop {
        _read {
            yield Pop(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Pop(heap: self)
            self = Heap()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Pop Type

extension Heap where Element: Copyable {
    /// Namespace for pop operations.
    public struct Pop {
        @usableFromInline
        var heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Pop Operations

extension Heap.Pop where Element: Copyable {
    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min() throws(Heap<Element>.Error) -> Element {
        guard let element = heap._removeMin() else {
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
        guard let element = heap._removeMax() else {
            throw .empty(.init())
        }
        return element
    }
}
