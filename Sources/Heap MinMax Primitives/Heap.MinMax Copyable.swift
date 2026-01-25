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

// MARK: - Sequence Init (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Creates a min-max heap from a sequence using O(n) heapification.
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>) {
        self.init()

        for element in elements {
            _appendWithoutHeapify(element)
        }

        if _storage.header > 1 {
            _heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: _storage.capacity)
            let currentCount = _storage.header
            _storage._copyAllElements(to: newStorage, count: currentCount)
            newStorage.header = currentCount
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
        _makeUnique()
        _insert(element)
    }
}

// MARK: - Peek/Pop/Take Methods

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Returns the minimum element without removing it.
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage._readElement(at: 0)
    }

    /// Returns the maximum element without removing it.
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage._readElement(at: 0) }
        if count == 2 { return _storage._readElement(at: 1) }

        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        return e1 < e2 ? e2 : e1
    }

    /// Removes and returns the minimum element.
    @inlinable
    public mutating func popMin() throws(Error) -> Element {
        _makeUnique()
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the maximum element.
    @inlinable
    public mutating func popMax() throws(Error) -> Element {
        _makeUnique()
        guard let element = _removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the minimum element, or nil if empty.
    @inlinable
    public mutating func takeMin() -> Element? {
        _makeUnique()
        return _removeMin()
    }

    /// Removes and returns the maximum element, or nil if empty.
    @inlinable
    public mutating func takeMax() -> Element? {
        _makeUnique()
        return _removeMax()
    }
}

// MARK: - Equatable (Copyable only)

extension Heap.MinMax: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._storage._readElement(at: i) != rhs._storage._readElement(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable only)

extension Heap.MinMax: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_storage._readElement(at: i))
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
        let _storage: Heap<Element>.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        init(_storage: Heap<Element>.Storage) {
            self._storage = _storage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _storage.header else { return nil }
            defer { _index += 1 }
            return _storage._readElement(at: _index)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage: _storage)
    }
}
