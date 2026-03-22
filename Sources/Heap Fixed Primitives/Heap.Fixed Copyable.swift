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

public import Sequence_Primitives
internal import Property_Primitives
public import Buffer_Linear_Primitives

// MARK: - Heap.Fixed Iterator

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Iterator for Heap.Fixed elements.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Bounded.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Bounded.Iterator) {
            self._inner = _inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @_lifetime(self: immortal)
        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }
}

// MARK: - Sequence.Protocol Conformance

extension Heap.Fixed: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Returns an iterator over the heap's elements in heap order.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }

    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Sequence.Clearable Conformance

extension Heap.Fixed: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged (fixed-capacity heap).
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all()
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.Fixed: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    /// The capacity remains unchanged.
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
}

// MARK: - Conditional Drain

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
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

// MARK: - Property Accessors

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain>.View(&self)
            yield &view
        }
    }

}

public import Heap_Primitives_Core

// MARK: - Swift.Sequence Conformance
//
// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
// Separate module to avoid constraint poisoning on Core types.

extension Heap.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
//    @inlinable
//    public var underestimatedCount: Int { Int(bitPattern: count) }
}
