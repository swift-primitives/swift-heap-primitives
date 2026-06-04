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
public import Buffer_Linear_Bounded_Primitive
public import Buffer_Linear_Bounded_Primitives
public import Property_Primitives
import Index_Primitives

// MARK: - Namespaces

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {
        public typealias View = Heap<Element>.Fixed.Property<Remove>.Inout.Typed<Element>
    }
}

// MARK: - Property Typealias

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap.Fixed>
}

// MARK: - Properties

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _buffer.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _buffer.isFull }

    /// The fixed capacity of this heap.
    @inlinable
    public var capacity: Heap.Index.Count { _buffer.capacity }
}

// MARK: - Internal Heap Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let insertionIndex = _buffer.count.map(Ordinal.init)
        _ = _buffer.append(element)
        bubbleUp(insertionIndex)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == .one {
            return _buffer.remove.last()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)
        _buffer.swap(at: .zero, with: lastIndex)
        let removed = _buffer.remove.last()
        trickleDown(.zero)
        return removed
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

// NOTE: Identical to Heap.bubbleUp/trickleDown — duplicated because
// Buffer.Linear variants are distinct types with no shared protocol.
// If buffer-primitives adds a shared protocol, consolidate.

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
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

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
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

// MARK: - Heapify

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
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

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Pushes an element onto the heap.
    ///
    /// Returns an ``Outcome`` indicating whether the element was inserted
    /// or returned due to overflow.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: consuming Element) -> Heap.Push.Outcome {
        guard !isFull else {
            return .overflow(element)
        }
        insert(element)
        return .inserted
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
    /// - Throws: ``Fixed/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(Heap.Fixed.Error) -> Element {
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }
}

// MARK: - Remove Accessor

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.Fixed = ...
    /// heap.remove.all()  // Remove all elements (capacity unchanged)
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

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.Fixed.Remove,
    Base == Heap<Element>.Fixed,
    Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged (fixed-capacity heap).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        while !(base.value._buffer.isEmpty) {
            _ = base.value._buffer.remove.last()
        }
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the priority element.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > .zero else { return nil }
        return body(_buffer[.zero])
    }

    // Note: borrowing `forEach` is inherited from the Iterable floor (ops module).
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }

    /// Pushes an element onto the heap (CoW-aware).
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: Element) -> Heap.Push.Outcome {
        makeUnique()
        guard !isFull else {
            return .overflow(element)
        }
        insert(element)
        return .inserted
    }

    /// Takes and returns the priority element, or nil if empty (CoW-aware).
    @inlinable
    public var take: Element? {
        mutating get {
            makeUnique()
            return removePriority()
        }
    }

    /// Pops and returns the priority element (CoW-aware).
    @inlinable
    public mutating func pop() throws(Heap.Fixed.Error) -> Element {
        makeUnique()
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.Fixed.Remove,
    Base == Heap<Element>.Fixed,
    Element: Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap (CoW-aware).
    ///
    /// The capacity remains unchanged (fixed-capacity heap).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        base.value.makeUnique()
        base.value._buffer.remove.all()
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Returns the priority element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the priority element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !isEmpty else { return nil }
        return _buffer[.zero]
    }

    /// Returns the element at the given typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Heap.Index) -> Element? {
        guard navigate.isValid(index) else { return nil }
        return _buffer[index]
    }
}

// MARK: - Drain (Copyable)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    /// The capacity remains unchanged. Elements are drained in heap order,
    /// which is **not** sorted order.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        while !_buffer.isEmpty {
            body(_buffer.remove.last())
        }
    }

    /// Drains elements in priority order while the predicate returns true.
    ///
    /// Repeatedly peeks at the priority element; if the predicate returns true,
    /// takes (consumes) the element and passes it to body; if false, stops.
    /// The heap survives with remaining elements intact.
    ///
    /// - Parameters:
    ///   - predicate: A closure that receives a borrowed reference to the next element.
    ///     Return `true` to drain it, `false` to stop.
    ///   - body: A closure that receives each drained element with ownership.
    /// - Complexity: O(k log n) where k is the number of elements drained.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        makeUnique()
        while let element = peek, predicate(element) {
            body(take!)
        }
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Creates a fixed heap from a sequence.
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - capacity: Maximum number of elements. Must be non-negative.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
    /// - Note: If elements exceeds capacity, only the first `capacity` elements are kept.
    /// - Complexity: O(n)
    @inlinable
    public init(
        _ elements: some Swift.Sequence<Element>,
        capacity: Int,
        order: Heap.Order = .ascending
    ) throws(Heap.Fixed.Error) {
        // Must call designated initializer from core module per cross-module init rules
        try self.init(capacity: capacity, order: order)

        for element in elements {
            if isFull { break }
            _ = _buffer.append(element)
        }

        if count > .one {
            heapify()
        }
    }
}

// MARK: - Truncate

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Heap.Index.Count) {
        guard newCount < count else { return }
        while _buffer.count > newCount {
            _ = _buffer.remove.last()
        }
    }
}

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count (CoW-aware).
    @inlinable
    public mutating func truncate(to newCount: Heap.Index.Count) {
        makeUnique()
        guard newCount < count else { return }
        while _buffer.count > newCount {
            _ = _buffer.remove.last()
        }
    }
}

// MARK: - Span Access
//
// The read-only `span` is the `Span.`Protocol`` witness, co-located in
// Heap.Fixed+Memory.Contiguous.Protocol.swift.

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// A mutable view of the heap's elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    ///   After modification, you may need to re-heapify.
    ///
    /// Rebuilt over `Buffer.Linear.Bounded`'s form-α `mutableSpan()` *method*
    /// (D1; the underlying property was dropped at the ⑤-(N) reparam — a generic
    /// substrate cannot vend a forwarding mutable-span property). The `<E>` pin is
    /// satisfied concretely (`_buffer`'s substrate is `Storage<Element>.Heap`).
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

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// A mutable view of the heap's elements (CoW-aware).
    ///
    /// Rebuilt over `Buffer.Linear.Bounded`'s form-α `mutableSpan()` *method* (D1).
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan()
        }
        @_lifetime(&self)
        _modify {
            makeUnique()
            var span = _buffer.mutableSpan()
            yield &span
        }
    }
}

// MARK: - Fixed Navigate Accessor

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap.Navigate {
        Heap.Navigate(_count: _buffer.count)
    }
}
