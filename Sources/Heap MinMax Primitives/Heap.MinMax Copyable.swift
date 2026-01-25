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
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: _storage.capacity)
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

// MARK: - Peek/Pop/Take Methods

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Returns the minimum element without removing it.
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage.read(at: .zero)
    }

    /// Returns the maximum element without removing it.
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage.read(at: .zero) }
        if count == 2 {
            let index = Heap<Element>.Index(__unchecked: (), position: 1)
            return _storage.read(at: index)
        }

        let idx1 = Heap<Element>.Index(__unchecked: (), position: 1)
        let idx2 = Heap<Element>.Index(__unchecked: (), position: 2)
        let e1 = _storage.read(at: idx1)
        let e2 = _storage.read(at: idx2)
        return e1 < e2 ? e2 : e1
    }

    /// Removes and returns the minimum element.
    @inlinable
    public mutating func popMin() throws(Error) -> Element {
        makeUnique()
        guard let element = removeMin() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the maximum element.
    @inlinable
    public mutating func popMax() throws(Error) -> Element {
        makeUnique()
        guard let element = removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the minimum element, or nil if empty.
    @inlinable
    public mutating func takeMin() -> Element? {
        makeUnique()
        return removeMin()
    }

    /// Removes and returns the maximum element, or nil if empty.
    @inlinable
    public mutating func takeMax() -> Element? {
        makeUnique()
        return removeMax()
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
        let _storage: Heap<Element>.Storage

        @usableFromInline
        var _index: Heap<Element>.Index = .zero

        @usableFromInline
        init(_storage: Heap<Element>.Storage) {
            self._storage = _storage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index.position.rawValue < _storage.count.rawValue else { return nil }
            let element = _storage.read(at: _index)
            _index = Heap<Element>.Index(__unchecked: (), position: _index.position.rawValue + 1)
            return element
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage: _storage)
    }
}
