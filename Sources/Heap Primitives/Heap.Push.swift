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

// MARK: - Push Tag

extension Heap where Element: Copyable {
    /// Phantom tag for push operations.
    ///
    /// Used with ``Property`` to provide namespaced push methods.
    public enum Push {}
}

// MARK: - Push Accessor (Copyable elements only)

extension Heap where Element: Copyable {
    /// Nested accessor for push operations.
    ///
    /// ```swift
    /// var heap = Heap<Int>()
    /// heap.push(42)                    // single element
    /// heap.push.contentsOf([1, 2, 3])  // bulk insert
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var push: Property<Push> {
        _read {
            yield Property(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Push> = Property(self)
            self = Heap()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Push Operations

extension Property_Primitives.Property {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func callAsFunction<E: Copyable & Comparable>(_ element: E)
    where Tag == Heap<E>.Push, Base == Heap<E> {
        base._insert(element)
    }

    /// Inserts multiple elements into the heap.
    ///
    /// Uses a heuristic to choose between per-element insertion
    /// and full re-heapification for optimal performance.
    ///
    /// - Parameter elements: The elements to insert.
    /// - Complexity: O(n + k) where k is the number of new elements.
    @inlinable
    public mutating func contentsOf<E: Copyable & Comparable>(_ elements: some Sequence<E>)
    where Tag == Heap<E>.Push, Base == Heap<E> {
        let origCount = base.count
        for element in elements {
            base._appendWithoutHeapify(element)
        }
        let newCount = base.count

        guard newCount > origCount, newCount > 1 else { return }

        // Heuristic: use Floyd's if k > 2n / log(n)
        let heuristicLimit = 2 * newCount / Swift.max(1, newCount._binaryLogarithm())
        let useFloyd = (newCount - origCount) > heuristicLimit

        if useFloyd {
            base._heapify()
        } else {
            for offset in origCount..<newCount {
                base._bubbleUp(Heap<E>.Node(offset: offset))
            }
        }
    }
}
