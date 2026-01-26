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

public import Heap_Primitives_Core
public import Range_Primitives

// MARK: - Sequence.Protocol Conformance

extension Heap.MinMax: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // makeIterator() is provided by Swift.Sequence conformance in Heap.MinMax Copyable.swift

    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { _storage.header }
}

// MARK: - Sequence.Clearable Conformance

extension Heap.MinMax: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all(keepingCapacity: false)
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.MinMax: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        (0..<_storage.count).forEach { index in
            body(_storage.move(at: index))
        }
        _storage.header = 0
    }
}

// MARK: - Property Accessors

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
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

    /// Accessor for forEach operations.
    public var forEach: Property<Sequence.ForEach>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach>.View(&self)
            yield &view
        }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Property<Sequence.Satisfies>.View {
        mutating _read {
            yield unsafe Property<Sequence.Satisfies>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Satisfies>.View(&self)
            yield &view
        }
    }

    /// Accessor for finding the first matching element.
    public var first: Property<Sequence.First>.View {
        mutating _read {
            yield unsafe Property<Sequence.First>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.First>.View(&self)
            yield &view
        }
    }

    /// Accessor for reduce operations.
    public var reduce: Property<Sequence.Reduce>.View {
        mutating _read {
            yield unsafe Property<Sequence.Reduce>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Reduce>.View(&self)
            yield &view
        }
    }

    /// Accessor for containment checks.
    public var contains: Property<Sequence.Contains>.View {
        mutating _read {
            yield unsafe Property<Sequence.Contains>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Contains>.View(&self)
            yield &view
        }
    }

    /// Accessor for drop operations.
    public var drop: Property<Sequence.Drop>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drop>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drop>.View(&self)
            yield &view
        }
    }

    /// Accessor for prefix operations.
    public var prefix: Property<Sequence.Prefix>.View {
        mutating _read {
            yield unsafe Property<Sequence.Prefix>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Prefix>.View(&self)
            yield &view
        }
    }
}


// MARK: - Sequence Init (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Creates a min-max heap from a sequence using O(n) heapification.
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>) {
        self.init()

        for element in elements {
            appendWithoutHeapify(element)
        }

        if _storage.header > 1 {
            heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap.Storage.create(minimumCapacity: _storage.capacity)
            let currentCount = _storage.count
            _storage.copy(to: newStorage, count: currentCount)
            newStorage.header = currentCount.rawValue
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }
}

// MARK: - CoW-aware Public Operations (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element) {
        makeUnique()
        insert(element)
    }
}


// MARK: - Equatable (Copyable only)

extension Heap.MinMax: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var result = true
        (0..<lhs._storage.count).forEach { index in
            if lhs._storage.read(at: index) != rhs._storage.read(at: index) {
                result = false
            }
        }
        return result
    }
}

// MARK: - Hashable (Copyable only)

extension Heap.MinMax: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        (0..<_storage.count).forEach { index in
            hasher.combine(_storage.read(at: index))
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable only)

extension Heap.MinMax: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Heap.MinMax: CustomStringConvertible {
    public var description: String {
        "Heap.MinMax(\(count) elements)"
    }
}
#endif

// MARK: - Sequence Conformance (Copyable only)

extension Heap.MinMax: Swift.Sequence where Element: Copyable {

    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Heap.Storage

        @usableFromInline
        let _end: Heap.Index.Count

        @usableFromInline
        var _index: Heap.Index = .zero

        @usableFromInline
        init(_storage: Heap.Storage) {
            self._storage = _storage
            self._end = _storage.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _end else { return nil }
            let element = _storage.read(at: _index)
            _index = (_index + 1)!
            return element
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage: _storage)
    }
}

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Non-mutating accessor for peeking at min/max elements.
    ///
    /// Use this for read-only access:
    ///
    /// ```swift
    /// let heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.peek.min  // 1
    /// let largest = heap.peek.max   // 8
    /// ```
    @inlinable
    public var peek: Property<Peek>.Typed<Element> {
        Property_Primitives.Property.Typed(self)
    }
}

extension Property_Primitives.Property.Typed
where Tag == Heap<Element>.MinMax.Peek,
      Base == Heap<Element>.MinMax,
      Element: Copyable & Comparison.`Protocol`
{
    /// The minimum element, or `nil` if the heap is empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        guard base._storage.header > 0 else { return nil }
        return base._storage.read(at: .zero)
    }

    /// The maximum element, or `nil` if the heap is empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        guard base._storage.header > 0 else { return nil }
        let count = base._storage.count
        if count == 1 {
            return base._storage.read(at: .zero)
        }
        if count == 2 {
            let index = Heap<Element>.Index(__unchecked: (), position: 1)
            return base._storage.read(at: index)
        }

        let idx1 = Heap<Element>.Index(__unchecked: (), position: 1)
        let idx2 = Heap<Element>.Index(__unchecked: (), position: 2)
        let e1 = base._storage.read(at: idx1)
        let e2 = base._storage.read(at: idx2)
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Min Accessor (Property.View.Typed)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for minimum element operations.
    ///
    /// Use this to peek, pop, or take the minimum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.min.peek      // 1 (without removing)
    /// let removed = try heap.min.pop()  // 1 (removes and returns)
    /// let taken = heap.min.take         // next min or nil
    /// ```
    public var min: Property<Min>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Min>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Min>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Heap<Element>.MinMax.Min,
      Base == Heap<Element>.MinMax,
      Element: Copyable & Comparison.`Protocol`
{
    /// Returns the minimum element without removing it.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !(unsafe base.pointee.isEmpty) else { return nil }
        return unsafe base.pointee._storage.read(at: .zero)
    }

    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
        unsafe base.pointee.makeUnique()
        guard let element = unsafe base.pointee.removeMin() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        unsafe base.pointee.makeUnique()
        return unsafe base.pointee.removeMin()
    }
}

// MARK: - Max Accessor (Property.View.Typed)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for maximum element operations.
    ///
    /// Use this to peek, pop, or take the maximum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let largest = heap.max.peek       // 8 (without removing)
    /// let removed = try heap.max.pop()  // 8 (removes and returns)
    /// let taken = heap.max.take         // next max or nil
    /// ```
    public var max: Property<Max>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Max>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Max>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Heap<Element>.MinMax.Max,
      Base == Heap<Element>.MinMax,
      Element: Copyable & Comparison.`Protocol`
{
    /// Returns the maximum element without removing it.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !(unsafe base.pointee.isEmpty) else { return nil }
        let count = unsafe base.pointee.count
        if count == 1 {
            return unsafe base.pointee._storage.read(at: .zero)
        }
        if count == 2 {
            let index = Heap<Element>.Index(__unchecked: (), position: 1)
            return unsafe base.pointee._storage.read(at: index)
        }

        let idx1 = Heap<Element>.Index(__unchecked: (), position: 1)
        let idx2 = Heap<Element>.Index(__unchecked: (), position: 2)
        let e1 = unsafe base.pointee._storage.read(at: idx1)
        let e2 = unsafe base.pointee._storage.read(at: idx2)
        return e1 < e2 ? e2 : e1
    }

    /// Removes and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
        unsafe base.pointee.makeUnique()
        guard let element = unsafe base.pointee.removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        unsafe base.pointee.makeUnique()
        return unsafe base.pointee.removeMax()
    }
}
