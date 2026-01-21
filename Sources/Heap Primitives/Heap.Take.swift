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

// MARK: - Take Tag

extension Heap where Element: Copyable {
    /// Phantom tag for take (optional removal) operations.
    ///
    /// Used with ``Property`` to provide namespaced take properties.
    public enum Take {}
}

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
    public var take: Property<Take>.Typed<Element> {
        _read {
            yield Property.Typed(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Take>.Typed<Element> = Property.Typed(self)
            self = Heap()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Take Operations

extension Property_Primitives.Property.Typed
where Tag == Heap<Element>.Take, Base == Heap<Element>, Element: Copyable & Comparable {
    /// Removes and returns the minimum element, or `nil` if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var min: Element? {
        mutating get {
            base._removeMin()
        }
    }

    /// Removes and returns the maximum element, or `nil` if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var max: Element? {
        mutating get {
            base._removeMax()
        }
    }
}
