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

// MARK: - Peek Tag

extension Heap where Element: Copyable {
    /// Phantom tag for peek operations.
    ///
    /// Used with ``Property`` to provide namespaced peek properties.
    public enum Peek {}
}

// MARK: - Peek Accessor (Copyable elements only)

extension Heap where Element: Copyable {
    /// Nested accessor for peek operations.
    ///
    /// ```swift
    /// let heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// if let min = heap.peek.min { print(min) }  // 1
    /// if let max = heap.peek.max { print(max) }  // 5
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var peek: Property<Peek>.Typed<Element> {
        Property_Primitives.Property.Typed(self)
    }
}

// MARK: - Peek Operations

extension Property_Primitives.Property.Typed
where Tag == Heap<Element>.Peek, Base == Heap<Element>, Element: Copyable & Comparable {
    /// The minimum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        base._peekMin()
    }

    /// The maximum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        base._peekMax()
    }
}
