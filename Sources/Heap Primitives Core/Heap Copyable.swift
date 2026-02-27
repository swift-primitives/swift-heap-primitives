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

public import Property_Primitives
public import Buffer_Linear_Primitives


// MARK: - Sequence Init (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Creates a heap from a sequence using O(n) heapification.
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>, order: Order = .ascending) {
        self.order = order
        self._buffer = Buffer<Element>.Linear(minimumCapacity: .zero)

        for element in elements {
            appendWithoutHeapify(element)
        }

        if count > .one {
            heapify()
        }
    }
}

// MARK: - CoW-aware Public Operations (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap (CoW-aware).
    ///
    /// This method shadows the base `push(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func push(_ element: Element) {
        _buffer.ensureUnique()
        insert(element)
    }
}

// MARK: - Peek/Read Operations (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Returns the priority element without removing it.
    ///
    /// For `.ascending` order (min-heap), returns the minimum element.
    /// For `.descending` order (max-heap), returns the maximum element.
    ///
    /// - Returns: The priority element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !isEmpty else { return nil }
        return _buffer[.zero]
    }

    /// Replaces the priority element and returns the old value.
    @usableFromInline
    package mutating func replacePriority(with replacement: Element) -> Element {
        let removed = _buffer[.zero]
        _buffer[.zero] = replacement
        trickleDown(.zero)
        return removed
    }

    /// A read-only view into the underlying storage.
    ///
    /// The elements are in heap order, which is **not** sorted order.
    ///
    /// - Complexity: O(n) to copy elements.
    @inlinable
    public var unordered: Buffer<Element>.Linear {
        var result = Buffer<Element>.Linear(minimumCapacity: count)
        var idx: Heap.Index = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            result.append(_buffer[idx])
            idx += .one
        }
        return result
    }
}

// MARK: - Element Access via Index (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Returns the element at the given typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Heap.Index) -> Element? {
        guard navigate.isValid(index) else { return nil }
        return _buffer[index]
    }
}

// MARK: - Pop (Throwing removal)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Removes and returns the priority element.
    ///
    /// For `.ascending` order (min-heap), removes the minimum element.
    /// For `.descending` order (max-heap), removes the maximum element.
    ///
    /// - Returns: The priority element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(Heap.Error) -> Element {
        _buffer.ensureUnique()
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }
}

// MARK: - Take (Optional removal)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Removes and returns the priority element, or `nil` if empty.
    ///
    /// Use `take` when empty is a normal state (priority queue drain):
    /// ```swift
    /// var heap = Heap<Int>(order: .ascending)
    /// while let element = heap.take {
    ///     process(element)
    /// }
    /// ```
    ///
    /// - Returns: The priority element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        mutating get {
            _buffer.ensureUnique()
            return removePriority()
        }
    }
}

// MARK: - Conditional Drain

extension Heap where Element: Copyable & Comparison.`Protocol` {
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
        _buffer.ensureUnique()
        while let element = peek, predicate(element) {
            body(take!)
        }
    }
}

// MARK: - Equatable (Copyable only)

extension Heap: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        guard lhs.order == rhs.order else { return false }
        var idx: Heap.Index = .zero
        let end = lhs.count.map(Ordinal.init)
        while idx < end {
            if lhs._buffer[idx] != rhs._buffer[idx] { return false }
            idx += .one
        }
        return true
    }
}

// MARK: - Hashable (Copyable only)

extension Heap: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        hasher.combine(order)
        var idx: Heap.Index = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            hasher.combine(_buffer[idx])
            idx += .one
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable only)

extension Heap: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements, order: .ascending)
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Heap: CustomStringConvertible {
    public var description: String {
        "Heap(\(count) elements, order: \(order))"
    }
}
#endif

// MARK: - Sequence Conformance (Copyable only)

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
