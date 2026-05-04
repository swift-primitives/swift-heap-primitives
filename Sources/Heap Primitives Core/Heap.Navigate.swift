// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Navigate Namespace

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for index navigation operations.
    ///
    /// Navigation methods compute parent and child indices in the binary heap
    /// structure without compound method names.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let heap: Heap<Int> = [5, 3, 8, 1]
    ///
    /// if let root = heap.root {
    ///     let left = heap.navigate.child(.left, of: root)
    ///     let right = heap.navigate.child(.right, of: root)
    ///
    ///     if let left = left {
    ///         let parent = heap.navigate.parent(of: left)
    ///         // parent == root
    ///     }
    /// }
    /// ```
    public struct Navigate: Sendable, Hashable {
        /// Child position in the binary heap.
        public enum Child: Sendable, Hashable {
            /// Left child (position `2i + 1`).
            case left
            /// Right child (position `2i + 2`).
            case right
        }

        @usableFromInline
        internal let _count: Index.Count

        @inlinable
        package init(_count: Index.Count) {
            self._count = _count
        }

        /// Returns the index of the parent of the element at the given index.
        ///
        /// - Parameter index: The index of the child element.
        /// - Returns: Index of the parent, or `nil` if the index is the root.
        @inlinable
        public func parent(of index: Heap.Index) -> Heap.Index? {
            guard index > .zero else { return nil }
            let pos = index.position.rawValue
            return Heap.Index(_unchecked: Ordinal((pos &- 1) / 2))
        }

        /// Returns the index of the specified child of the element at the given index.
        ///
        /// - Parameters:
        ///   - child: Which child to get (`.left` or `.right`).
        ///   - index: The index of the parent element.
        /// - Returns: Index of the child, or `nil` if no such child exists.
        @inlinable
        public func child(_ child: Child, of index: Heap.Index) -> Heap.Index? {
            let pos = index.position.rawValue
            let childPos: UInt
            switch child {
            case .left: childPos = 2 &* pos &+ 1
            case .right: childPos = 2 &* pos &+ 2
            }
            let result = Heap.Index(_unchecked: Ordinal(childPos))
            guard result < _count else { return nil }
            return result
        }

        /// First non-leaf index for Floyd's bottom-up heapify, or `nil` if count <= 1.
        ///
        /// Raw arithmetic is principled: Cardinal has no division ([IMPL-001]).
        @inlinable
        package var lastNonLeaf: Heap.Index? {
            let raw = _count.underlying.rawValue
            guard raw > 1 else { return nil }
            return Heap.Index(_unchecked: Ordinal((raw / 2) &- 1))
        }

        /// Index of the left child of root (position 1).
        @inlinable
        package static var leftChildOfRoot: Heap.Index {
            Heap.Index(_unchecked: Ordinal(1))
        }

        /// Index of the right child of root (position 2).
        @inlinable
        package static var rightChildOfRoot: Heap.Index {
            Heap.Index(_unchecked: Ordinal(2))
        }

        /// Returns whether the given index represents a valid position.
        ///
        /// - Parameter index: The index to validate.
        /// - Returns: `true` if the index is within bounds.
        @inlinable
        public func isValid(_ index: Heap.Index) -> Bool {
            index >= .zero && index < _count
        }
    }
}

// MARK: - Heap Navigate Accessor

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    ///
    /// - Returns: Index of root element (position 0), or `nil` if empty.
    /// - Complexity: O(1)
    @inlinable
    public var root: Heap.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    ///
    /// Use this to compute parent and child indices:
    ///
    /// ```swift
    /// let parent = heap.navigate.parent(of: index)
    /// let leftChild = heap.navigate.child(.left, of: index)
    /// let rightChild = heap.navigate.child(.right, of: index)
    /// ```
    @inlinable
    public var navigate: Navigate {
        Navigate(_count: count)
    }
}




