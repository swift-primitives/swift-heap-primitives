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
    public var peek: Peek {
        Peek(heap: self)
    }
}

// MARK: - Peek Type

extension Heap where Element: Copyable {
    /// Namespace for peek operations.
    public struct Peek {
        @usableFromInline
        let heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Peek Operations

extension Heap.Peek where Element: Copyable {
    /// The minimum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        heap._peekMin()
    }

    /// The maximum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        heap._peekMax()
    }
}
