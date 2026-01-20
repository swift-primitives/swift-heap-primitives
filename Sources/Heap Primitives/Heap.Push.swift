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
    public var push: Push {
        _read {
            yield Push(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Push(heap: self)
            self = Heap()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Push Type

extension Heap where Element: Copyable {
    /// Namespace for push operations.
    public struct Push {
        @usableFromInline
        var heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Push Operations

extension Heap.Push where Element: Copyable {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func callAsFunction(_ element: Element) {
        heap._insert(element)
    }

    /// Inserts multiple elements into the heap.
    ///
    /// Uses a heuristic to choose between per-element insertion
    /// and full re-heapification for optimal performance.
    ///
    /// - Parameter elements: The elements to insert.
    /// - Complexity: O(n + k) where k is the number of new elements.
    @inlinable
    public mutating func contentsOf(_ elements: some Sequence<Element>) {
        let origCount = heap.count
        for element in elements {
            heap._appendWithoutHeapify(element)
        }
        let newCount = heap.count

        guard newCount > origCount, newCount > 1 else { return }

        // Heuristic: use Floyd's if k > 2n / log(n)
        let heuristicLimit = 2 * newCount / Swift.max(1, newCount._binaryLogarithm())
        let useFloyd = (newCount - origCount) > heuristicLimit

        if useFloyd {
            heap._heapify()
        } else {
            for offset in origCount..<newCount {
                heap._bubbleUp(Heap.Node(offset: offset))
            }
        }
    }
}
