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

public import Heap_Primitive
public import Storage_Small_Primitives
public import Storage_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Buffer_Linear_Small_Primitive
public import Buffer_Linear_Small_Primitives
public import Property_Primitives
import Index_Primitives

// MARK: - Namespaces

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {
        public typealias View = Heap<Element>.Small<inlineCapacity>.Property<Remove>.Inout.Typed<Element>.Valued<inlineCapacity>
    }
}

// MARK: - Property Typealias

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>.Small<inlineCapacity>>
}

// MARK: - Remove Accessor

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.Small<8> = ...
    /// heap.remove.all()  // Remove all elements
    /// ```
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed.Valued
where
    Tag == Heap<Element>.Small<n>.Remove,
    Base == Heap<Element>.Small<n>,
    Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// Resets to inline mode if spilled.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        base.value._buffer.removeAll()
    }
}

// MARK: - Properties

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _buffer.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity (inline or heap).
    @inlinable
    public var capacity: Index<Element>.Count { _buffer.capacity }

    /// Whether the heap is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { _buffer.substrate.isSpilled }
}

// MARK: - Internal Heap Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let insertionIndex = _buffer.count.map(Ordinal.init)
        _buffer.append(element)
        bubbleUp(insertionIndex)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == .one {
            return _buffer.removeLast()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)
        _buffer.swap(at: .zero, with: lastIndex)
        let removed = _buffer.removeLast()
        trickleDown(.zero)
        return removed
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

// NOTE: Identical to Heap.bubbleUp/trickleDown — duplicated because
// Buffer.Linear variants are distinct types with no shared protocol.
// If buffer-primitives adds a shared protocol, consolidate.

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    ///
    /// For ascending order (min-heap): element bubbles up while smaller than parent.
    /// For descending order (max-heap): element bubbles up while larger than parent.
    @usableFromInline
    package mutating func bubbleUp(_ index: Heap.Index) {
        var current = index
        let nav = navigate

        switch order {
        case .ascending:
            while let parent = nav.parent(of: current) {
                if _buffer[current] < _buffer[parent] {
                    _buffer.swap(at: current, with: parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if _buffer[parent] < _buffer[current] {
                    _buffer.swap(at: current, with: parent)
                    current = parent
                } else {
                    break
                }
            }
        }
    }
}

// MARK: - Trickle Down (Single-Ended Heap)

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    ///
    /// For ascending order (min-heap): element trickles down to larger of children.
    /// For descending order (max-heap): element trickles down to smaller of children.
    @usableFromInline
    package mutating func trickleDown(_ startIndex: Heap.Index) {
        var current = startIndex
        let nav = navigate

        switch order {
        case .ascending:
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                if _buffer[leftChild] < _buffer[smallest] {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if _buffer[rightChild] < _buffer[smallest] {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                _buffer.swap(at: current, with: smallest)
                current = smallest
            }

        case .descending:
            while let leftChild = nav.child(.left, of: current) {
                var largest = current

                if _buffer[largest] < _buffer[leftChild] {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if _buffer[largest] < _buffer[rightChild] {
                        largest = rightChild
                    }
                }

                if largest == current { break }

                _buffer.swap(at: current, with: largest)
                current = largest
            }
        }
    }
}

// MARK: - Heapify (Floyd's Algorithm)

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        guard var idx = navigate.lastNonLeaf else { return }
        while true {
            trickleDown(idx)
            guard idx > .zero else { break }
            idx = try! idx.predecessor.exact()
        }
    }
}

// MARK: - Core Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Pushes an element onto the heap.
    ///
    /// If the heap exceeds inline capacity, elements are moved to heap storage.
    /// Push operations never fail - the heap grows automatically.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(log n) amortized, O(n) when spilling to heap.
    @inlinable
    public mutating func push(_ element: consuming Element) {
        insert(element)
    }

    /// Takes and returns the priority element, or nil if empty.
    ///
    /// - Returns: The priority element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        mutating get {
            removePriority()
        }
    }

    /// Pops and returns the priority element.
    ///
    /// - Returns: The priority element.
    /// - Throws: ``Small/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(Heap.Small<inlineCapacity>.Error) -> Element {
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the priority element.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > .zero else { return nil }
        return body(_buffer[.zero])
    }

    // Note: borrowing `forEach` is inherited from the Iterable floor (ops module).
}

// MARK: - Truncate

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Heap.Index.Count) {
        guard newCount < count else { return }
        while count > newCount {
            _ = _buffer.removeLast()
        }
    }
}

// MARK: - Span Access
//
// The read-only `span` is the `Span.`Protocol`` witness, co-located in
// Heap.Small+Memory.Contiguous.Protocol.swift.

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Mutable span of the heap elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan()
        }
        @_lifetime(&self)
        _modify {
            var span = _buffer.mutableSpan()
            yield &span
        }
    }
}

// MARK: - Small Navigate Accessor

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap.Navigate {
        Heap.Navigate(_count: count)
    }
}
