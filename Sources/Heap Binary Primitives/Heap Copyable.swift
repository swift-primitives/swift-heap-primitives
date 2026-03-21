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
public import Property_Primitives
public import Buffer_Linear_Primitives
public import Heap_Primitives_Core


// MARK: - Swift.Sequence Conformance (Copyable only)

extension Heap: Swift.Sequence where Element: Copyable {

    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Iterator) {
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

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }
}

// MARK: - Sequence.Protocol Conformance

extension Heap: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // makeIterator() is provided by Swift.Sequence conformance above.

    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Sequence.Clearable Conformance

extension Heap: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all(keepingCapacity: false)
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _buffer.ensureUnique()
        while !_buffer.isEmpty {
            body(_buffer.remove.last())
        }
    }
}

// MARK: - Drain Property Accessor

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    ///
    /// Draining removes all elements from the heap, passing each to a closure
    /// with ownership transferred. The heap survives but is empty after draining.
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.drain { element in
    ///     print(element)  // ownership transferred
    /// }
    /// // heap is now empty but still usable
    /// heap.push(10)  // OK
    /// ```
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
