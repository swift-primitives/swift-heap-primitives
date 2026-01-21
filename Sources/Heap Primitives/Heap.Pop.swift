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

import Property_Primitives

// MARK: - Pop Tag

extension Heap where Element: Copyable {
    /// Phantom tag for pop operations.
    ///
    /// Used with ``Property`` to provide namespaced pop methods.
    public enum Pop {}
}

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
    public var pop: Property<Pop> {
        _read {
            yield Property(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Pop> = Property(self)
            self = Heap()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Pop Operations

extension Property_Primitives.Property {
    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min<E: Copyable & Comparable>() throws(Heap<E>.Error) -> E
    where Tag == Heap<E>.Pop, Base == Heap<E> {
        guard let element = base._removeMin() else {
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
    public mutating func max<E: Copyable & Comparable>() throws(Heap<E>.Error) -> E
    where Tag == Heap<E>.Pop, Base == Heap<E> {
        guard let element = base._removeMax() else {
            throw .empty(.init())
        }
        return element
    }
}
