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
        internal init(_count: Index.Count) {
            self._count = _count
        }

        /// Returns the index of the parent of the element at the given index.
        ///
        /// - Parameter index: The index of the child element.
        /// - Returns: Index of the parent, or `nil` if the index is the root.
        @inlinable
        public func parent(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
            guard index.position > 0 else { return nil }
            return try? Heap<Element>.Index((index.position.rawValue - 1) / 2)
        }

        /// Returns the index of the specified child of the element at the given index.
        ///
        /// - Parameters:
        ///   - child: Which child to get (`.left` or `.right`).
        ///   - index: The index of the parent element.
        /// - Returns: Index of the child, or `nil` if no such child exists.
        @inlinable
        public func child(_ child: Child, of index: Heap<Element>.Index) -> Heap<Element>.Index? {
            let childPosition: Int
            switch child {
            case .left: childPosition = 2 * index.position.rawValue + 1
            case .right: childPosition = 2 * index.position.rawValue + 2
            }
            guard childPosition < _count.rawValue else { return nil }
            return try? Heap<Element>.Index(childPosition)
        }

        /// Returns whether the given index represents a valid position.
        ///
        /// - Parameter index: The index to validate.
        /// - Returns: `true` if the index is within bounds.
        @inlinable
        public func isValid(_ index: Heap<Element>.Index) -> Bool {
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
    public var root: Heap<Element>.Index? {
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

// MARK: - Fixed Navigate Accessor

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap<Element>.Navigate {
        Heap<Element>.Navigate(_count: count)
    }
}

// MARK: - Static Navigate Accessor

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap<Element>.Navigate {
        Heap<Element>.Navigate(_count: count)
    }
}

// MARK: - Small Navigate Accessor

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap<Element>.Navigate {
        Heap<Element>.Navigate(_count: count)
    }
}
