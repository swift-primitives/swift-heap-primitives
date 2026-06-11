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
public import Column_Primitives
public import Shared_Primitive
public import Property_Primitives
import Index_Primitives

// The fixed-capacity operation surface, generic over element copyability.
// Every mutation crosses the stored `Shared` column through the gate-first
// scoped accessor (`withUnique` — a no-op gate on the statically-unique
// `~Copyable`-element lane, the CoW restore on the `Copyable`-element lane),
// so ONE body serves both lanes; the hand-rolled `makeUnique` CoW and its
// `Copyable` shadow methods are deleted (the A-1 reshape — `Shared` supplies
// CoW). Unlike the growable column, `Shared` pins no span forms for the
// bounded column, so the scoped span pair here crosses the box through the
// generic devices (`withColumn` / `withUnique`) — the sanctioned
// family-pins-its-own-ops path.

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
    public var isFull: Bool { _buffer.count >= requestedCapacity }

    /// The fixed capacity of this heap.
    ///
    /// The underlying storage may round its physical capacity up; this is the
    /// heap's contract bound — `push` rejects at exactly this count.
    @inlinable
    public var capacity: Heap.Index.Count { requestedCapacity }
}

// MARK: - Column-Level Heap Algorithms (static; run inside the withUnique gate)

// NOTE: Identical to the base Heap's column algorithms — duplicated because
// Column.Heap and Column.Bounded are distinct types with no shared protocol
// surface for these ops. If buffer-primitives adds one, consolidate.

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving the element at `index` up.
    @usableFromInline
    package static func bubbleUp(
        _ column: inout Column.Bounded<Element>,
        at index: Heap.Index,
        order: Heap.Order
    ) {
        var current = index
        let nav = Heap.Navigate(_count: column.count)

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
    @usableFromInline
    package static func trickleDown(
        _ column: inout Column.Bounded<Element>,
        at startIndex: Heap.Index,
        order: Heap.Order
    ) {
        var current = startIndex
        let nav = Heap.Navigate(_count: column.count)

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
        _ column: inout Column.Bounded<Element>,
        order: Heap.Order
    ) {
        guard var idx = Heap.Navigate(_count: column.count).lastNonLeaf else { return }
        while true {
            Self.trickleDown(&column, at: idx, order: order)
            guard idx > .zero else { break }
            idx = try! idx.predecessor.exact()
        }
    }

    /// Removes and returns the priority element from the open column.
    @usableFromInline
    package static func removePriority(
        from column: inout Column.Bounded<Element>,
        order: Heap.Order
    ) -> Element? {
        guard !column.isEmpty else { return nil }

        if column.count == .one {
            return .some(column.remove.last())
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = column.count.subtract.saturating(.one).map(Ordinal.init)
        column.swap(at: .zero, with: lastIndex)
        let removed = column.remove.last()
        Self.trickleDown(&column, at: .zero, order: order)
        return .some(removed)
    }
}

// MARK: - Internal Heap Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Appends element without maintaining heap property (for bulk init).
    ///
    /// - Precondition: not full at the contract bound (callers guard `isFull`).
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        // The payload-threading form ([MEM-OWN-017]); the physical capacity is
        // at least the contract bound, so the guarded append cannot reject.
        _buffer.withUnique(consuming: element) { column, element in
            _ = column.append(element)
        }
    }

    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let order = self.order
        _buffer.withUnique { Self.heapify(&$0, order: order) }
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        let order = self.order
        return _buffer.withUnique { Self.removePriority(from: &$0, order: order) }
    }
}

// MARK: - Core Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Pushes an element onto the heap.
    ///
    /// Returns an ``Heap/Push/Outcome`` indicating whether the element was
    /// inserted or returned due to overflow.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n), O(n) if a CoW copy is triggered
    @inlinable
    @discardableResult
    public mutating func push(_ element: consuming Element) -> Heap.Push.Outcome {
        // The heap's contract is the REQUESTED capacity (the physical
        // allocation may round up); reject at the contract bound first.
        guard !isFull else {
            return .overflow(element)
        }
        let order = self.order
        // The payload-threading form ([MEM-OWN-017]): the element crosses the
        // box as a `consuming` closure PARAMETER; the column's `append`
        // returns the rejected element when the physical capacity is
        // exhausted, threaded OUT through the gate.
        return _buffer.withUnique(consuming: element) { column, element in
            let insertionIndex = column.count.map(Ordinal.init)
            guard let rejected = column.append(element) else {
                Self.bubbleUp(&column, at: insertionIndex, order: order)
                return .inserted
            }
            return .overflow(rejected)
        }
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
    /// - Throws: ``Heap/Fixed/Error/empty`` if the heap is empty.
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
        base.value._buffer.withUnique { $0.remove.all() }
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

    // Note: borrowing `forEach` is a plain member over the column's scoped
    // borrowing access (ops module).
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
        _buffer.withUnique { column in
            while !column.isEmpty {
                body(column.remove.last())
            }
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
        let order = self.order
        _buffer.withUnique { column in
            while !column.isEmpty, predicate(column[.zero]) {
                guard let element = Self.removePriority(from: &column, order: order) else {
                    return
                }
                body(element)
            }
        }
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Creates a fixed heap from a sequence.
    ///
    /// This is a constructing `Copyable` site: the inner `init(capacity:order:)`
    /// resolves to the clone-capturing twin, so copies of the result can
    /// restore uniqueness (CoW).
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - capacity: Maximum number of elements. Must be non-negative.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Heap/Fixed/Error/invalidCapacity`` if capacity is negative.
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
            appendWithoutHeapify(element)
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
        _buffer.withUnique { $0.truncate(to: newCount) }
    }
}

// MARK: - Scoped Span Access

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Calls `body` with a read-only span over the heap's elements in heap
    /// order (which is **not** sorted order).
    ///
    /// The scoped form replaces the former `span` property (the withdrawn
    /// `Span.Protocol` witness): a returning span cannot be forwarded out of
    /// the stored `Shared` column's class hop (the coroutine-window rule), so
    /// the region view is scoped. Reads never need the uniqueness gate.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func withSpan<R, Failure: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        try _buffer.withColumn { column throws(Failure) in
            try body(column.span)
        }
    }

    /// Calls `body` with a mutable span over the heap's elements
    /// (CoW-checked FIRST: uniqueness is restored before any mutable view
    /// exists).
    ///
    /// The scoped form replaces the former `mutableSpan` property (the
    /// coroutine-window rule, as above). ONE body serves both element lanes:
    /// the gate inside `withUnique` is the CoW restore on the
    /// `Copyable`-element lane and a no-op on the statically-unique
    /// `~Copyable`-element lane.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    ///   After modification, you may need to re-heapify.
    ///
    /// - Complexity: O(1), O(n) if a CoW copy is triggered
    @inlinable
    public mutating func withMutableSpan<R, Failure: Swift.Error>(
        _ body: (inout Swift.MutableSpan<Element>) throws(Failure) -> R
    ) throws(Failure) -> R {
        try _buffer.withUnique { column throws(Failure) in
            var span = column.mutableSpan
            return try body(&span)
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
