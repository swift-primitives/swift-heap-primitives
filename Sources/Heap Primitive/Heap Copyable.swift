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
import Index_Primitives

// The `Copyable`-element extras: surfaces that COPY elements out (`peek`,
// `unordered`, `element(at:)`), construct from copyable sequences, or drain
// with ownership transfer. The former CoW SHADOWS of the base ops
// (`push` / the explicit `ensureUnique` calls in `pop` / `take` / `drain`) are
// deleted: the base bodies cross the `Shared` column through the `withUnique`
// gate, which IS the CoW restore for `Copyable` elements — one body now serves
// both lanes (the A-1 reshape).

// MARK: - Sequence Init (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Creates a heap from a sequence using O(n) heapification.
    ///
    /// This is a constructing `Copyable` site: the column is wrapped through
    /// the clone-capturing `Shared` constructor, so copies of the result can
    /// restore uniqueness (CoW).
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>, order: Order = .ascending) {
        self.order = order
        self._buffer = Shared(Column.Heap<Element>(minimumCapacity: .zero))

        for element in elements {
            appendWithoutHeapify(element)
        }

        if count > .one {
            heapify()
        }
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
        let order = self.order
        return _buffer.withUnique(consuming: replacement) { column, replacement in
            let removed = column.replace(at: .zero, with: replacement)
            Self.trickleDown(&column, at: .zero, order: order)
            return removed
        }
    }

    /// A read-only view into the underlying storage.
    ///
    /// The elements are in heap order, which is **not** sorted order.
    /// The returned column is a fresh, independently-owned copy (the stored
    /// `Shared` column cannot be handed out by value).
    ///
    /// - Complexity: O(n) to copy elements.
    @inlinable
    public var unordered: Column.Heap<Element> {
        var result = Column.Heap<Element>(minimumCapacity: count)
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
    /// - Complexity: O(log n), O(n) if a CoW copy is triggered
    @inlinable
    public mutating func pop() throws(Heap.Error) -> Element {
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
            removePriority()
        }
    }
}

// MARK: - Drain (Copyable)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    /// Elements are drained in heap order, which is **not** sorted order.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _buffer.withUnique { column in
            while !column.isEmpty {
                body(column.removeLast())
            }
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

// MARK: - Equatable (Copyable only)

extension Heap: Equatable where Element: Equatable & Copyable {
    /// Compares two heaps for element-wise equality in heap order.
    ///
    /// Walks the live prefix through the column's seam subscript (the stored
    /// `Shared` column has no returning span — the element-keyed walk mirrors
    /// `Shared`'s own carriers).
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
    /// Hashes the count, order, and elements of this heap, in heap order.
    ///
    /// Count is combined first so the hash agrees with the equality walk's
    /// count guard.
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
