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

// MARK: - Replace Accessor (Copyable elements only)

extension Heap where Element: Copyable {
    /// Nested accessor for replace operations.
    ///
    /// Replace is more efficient than pop + push when you need to
    /// replace the extremum:
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// let oldMin = try heap.replace.min(with: 0)  // returns 1, heap now has 0
    /// let oldMax = try heap.replace.max(with: 9)  // returns 5, heap now has 9
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var replace: Replace {
        _read {
            yield Replace(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Replace(heap: self)
            self = Heap()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Replace Type

extension Heap where Element: Copyable {
    /// Namespace for replace operations.
    public struct Replace {
        @usableFromInline
        var heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Replace Operations

extension Heap.Replace where Element: Copyable {
    /// Replaces the minimum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty(.init())
        }
        return heap._replaceMin(with: replacement)
    }

    /// Replaces the maximum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original maximum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty(.init())
        }
        return heap._replaceMax(with: replacement)
    }
}
