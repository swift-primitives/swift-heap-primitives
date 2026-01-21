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

public import Index_Primitives

extension Heap where Element: ~Copyable {
    /// Type-safe index for heap elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Heap Index Semantics
    ///
    /// Position 0 is the root of the heap. For a min-max heap:
    /// - Even levels (0, 2, 4, ...) are min levels
    /// - Odd levels (1, 3, 5, ...) are max levels
    ///
    /// Parent-child relationships follow binary heap structure:
    /// - Parent of node at `i`: `(i - 1) / 2`
    /// - Children of node at `i`: `2i + 1` and `2i + 2`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let heapIdx: Heap<Int>.Index = 0
    /// // Get root element via index
    /// ```
    public typealias Index = Index_Primitives.Index<Element>
}

// MARK: - Index Operations

extension Heap where Element: ~Copyable {
    /// Returns the index of the root element, or nil if the heap is empty.
    ///
    /// - Returns: Index of root element (position 0), or `nil` if empty.
    @inlinable
    public func rootIndex() -> Index? {
        isEmpty ? nil : Index(0)
    }

    /// Returns the index of the parent of the element at the given index.
    ///
    /// - Parameter index: The index of the child element.
    /// - Returns: Index of the parent, or `nil` if the index is the root.
    @inlinable
    public func parentIndex(of index: Index) -> Index? {
        guard index.position > 0 else { return nil }
        return Index((index.position - 1) / 2)
    }

    /// Returns the index of the left child of the element at the given index.
    ///
    /// - Parameter index: The index of the parent element.
    /// - Returns: Index of the left child, or `nil` if no left child exists.
    @inlinable
    public func leftChildIndex(of index: Index) -> Index? {
        let childPosition = 2 * index.position + 1
        guard childPosition < count else { return nil }
        return Index(childPosition)
    }

    /// Returns the index of the right child of the element at the given index.
    ///
    /// - Parameter index: The index of the parent element.
    /// - Returns: Index of the right child, or `nil` if no right child exists.
    @inlinable
    public func rightChildIndex(of index: Index) -> Index? {
        let childPosition = 2 * index.position + 2
        guard childPosition < count else { return nil }
        return Index(childPosition)
    }

    /// Returns whether the given index represents a valid position in the heap.
    ///
    /// - Parameter index: The index to validate.
    /// - Returns: `true` if the index is within bounds.
    @inlinable
    public func isValid(_ index: Index) -> Bool {
        index.position >= 0 && index.position < count
    }
}

// MARK: - Element Access via Index

extension Heap where Element: Copyable {
    /// Returns the element at the given typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard isValid(index) else { return nil }
        return _storage._readElement(at: index.position)
    }
}

// MARK: - Bounded Heap Index Operations
// NOTE: Per [MEM-COPY-006], Heap.Bounded extensions are in Heap.swift
// to avoid breaking ~Copyable propagation.

// MARK: - Inline Heap Index Operations

extension Heap.Inline where Element: ~Copyable {
    /// Returns the index of the root element, or nil if the heap is empty.
    @inlinable
    public func rootIndex() -> Heap<Element>.Index? {
        isEmpty ? nil : Heap<Element>.Index(0)
    }

    /// Returns whether the given index represents a valid position in the heap.
    @inlinable
    public func isValid(_ index: Heap<Element>.Index) -> Bool {
        index.position >= 0 && index.position < _count
    }
}
