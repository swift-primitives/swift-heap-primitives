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

public import Buffer_Linear_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Column_Primitives
public import Shared_Primitive
public import Property_Primitives
import Index_Primitives

// The base operation surface, generic over element copyability. Every mutation
// crosses the stored `Shared` column through the gate-first scoped accessor
// (`withUnique` — a no-op gate on the statically-unique `~Copyable`-element
// lane, the CoW restore on the `Copyable`-element lane), so ONE body serves
// both lanes; the hand-rolled `ensureUnique` CoW and its `Copyable` shadow
// methods are deleted (the A-1 reshape — `Shared` supplies CoW). The sift
// algorithms run INSIDE the gate as static column-level functions: one gate
// per semantic mutation, not one per element access.

// MARK: - Namespaces

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {
        public typealias View = Heap<Element>.Property<Remove>.Inout.Typed<Element>
    }
}

// MARK: - Property Typealias

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>>
}

// MARK: - Properties

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _buffer.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }
}

// MARK: - Column-Level Heap Algorithms (static; run inside the withUnique gate)
//
// The former mutating sift methods restructured as static functions over the
// open column: a mutating method on `self` cannot run inside the gate (the
// closure already holds exclusive access to `_buffer`), so the algorithms
// take the uniquely-held column `inout` and the order by value.

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving the element at `index` up.
    ///
    /// For ascending order (min-heap): element bubbles up while smaller than parent.
    /// For descending order (max-heap): element bubbles up while larger than parent.
    @usableFromInline
    package static func bubbleUp(
        _ column: inout Column.Heap<Element>,
        at index: Heap.Index,
        order: Order
    ) {
        var current = index
        let nav = Navigate(_count: column.count)

        switch order {
        case .ascending:
            while let parent = nav.parent(of: current) {
                if column[current] < column[parent] {
                    column.swap(at: current, with: parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if column[parent] < column[current] {
                    column.swap(at: current, with: parent)
                    current = parent
                } else {
                    break
                }
            }
        }
    }

    /// Restores heap property by moving the element at `startIndex` down.
    ///
    /// For ascending order (min-heap): element trickles down to larger of children.
    /// For descending order (max-heap): element trickles down to smaller of children.
    @usableFromInline
    package static func trickleDown(
        _ column: inout Column.Heap<Element>,
        at startIndex: Heap.Index,
        order: Order
    ) {
        var current = startIndex
        let nav = Navigate(_count: column.count)

        switch order {
        case .ascending:
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                if column[leftChild] < column[smallest] {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if column[rightChild] < column[smallest] {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                column.swap(at: current, with: smallest)
                current = smallest
            }

        case .descending:
            while let leftChild = nav.child(.left, of: current) {
                var largest = current

                if column[largest] < column[leftChild] {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if column[largest] < column[rightChild] {
                        largest = rightChild
                    }
                }

                if largest == current { break }

                column.swap(at: current, with: largest)
                current = largest
            }
        }
    }

    /// Converts column contents to a valid heap in O(n) (Floyd's algorithm).
    @usableFromInline
    package static func heapify(
        _ column: inout Column.Heap<Element>,
        order: Order
    ) {
        guard var idx = Navigate(_count: column.count).lastNonLeaf else { return }
        while true {
            Self.trickleDown(&column, at: idx, order: order)
            guard idx > .zero else { break }
            idx = try! idx.predecessor.exact()
        }
    }

    /// Removes and returns the priority element from the open column
    /// (min for ascending, max for descending).
    @usableFromInline
    package static func removePriority(
        from column: inout Column.Heap<Element>,
        order: Order
    ) -> Element? {
        guard !column.isEmpty else { return nil }

        if column.count == .one {
            return .some(column.removeLast())
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = column.count.subtract.saturating(.one).map(Ordinal.init)
        column.swap(at: .zero, with: lastIndex)
        let removed = column.removeLast()
        Self.trickleDown(&column, at: .zero, order: order)
        return .some(removed)
    }
}

// MARK: - Core Operations (Internal)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Appends element without maintaining heap property (for bulk init).
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        // The payload-threading form: a `consuming` parameter cannot be
        // consumed inside a closure capture ([MEM-OWN-017]), so the element
        // crosses the box as a `consuming` closure PARAMETER.
        _buffer.withUnique(consuming: element) { column, element in
            column.append(element)
        }
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let order = self.order
        _buffer.withUnique(consuming: element) { column, element in
            let insertionIndex = column.count.map(Ordinal.init)
            column.append(element)
            Self.bubbleUp(&column, at: insertionIndex, order: order)
        }
    }

    /// Removes and returns the priority element (min for ascending, max for descending).
    @usableFromInline
    package mutating func removePriority() -> Element? {
        let order = self.order
        return _buffer.withUnique { Self.removePriority(from: &$0, order: order) }
    }

    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let order = self.order
        _buffer.withUnique { Self.heapify(&$0, order: order) }
    }
}

// MARK: - Public Mutating Operations

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n), O(n) if a CoW copy is triggered
    @inlinable
    public mutating func push(_ element: consuming Element) {
        insert(element)
    }
}

// MARK: - Remove Accessor

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.remove.all()                      // Remove all, release capacity
    /// heap.remove.all(keepingCapacity: true) // Remove all, keep capacity
    /// ```
    public var remove: Remove.View {
        mutating _read {
            yield .init(&self)
        }
        mutating _modify {
            var view: Remove.View = .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.Remove,
    Base == Heap<Element>,
    Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    ///   If `true`, the heap retains its current capacity.
    ///   If `false` (default), the capacity is released.
    /// - Complexity: O(n)
    @inlinable
    public func all(keepingCapacity: Bool = false) {
        base.value._buffer.withUnique { $0.removeAll(keepingCapacity: keepingCapacity) }
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element (root).
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the priority element.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > .zero else { return nil }
        return body(_buffer[.zero])
    }
}

// MARK: - Scoped Span Access

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Calls `body` with a read-only span over the heap's elements in heap
    /// order (which is **not** sorted order).
    ///
    /// The scoped form replaces the former `span` property (the withdrawn
    /// `Span.Protocol` witness): a returning span cannot be forwarded out of
    /// the stored `Shared` column's class hop (the coroutine-window rule), so
    /// the region view is scoped.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func withSpan<R, Failure: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        try _buffer.withSpan(body)
    }
}
