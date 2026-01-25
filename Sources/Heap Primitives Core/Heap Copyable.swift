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
public import Range_Primitives

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
        self._storage = Heap<Element>.Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)

        for element in elements {
            appendWithoutHeapify(element)
        }

        if _storage.header > 1 {
            heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: _storage.capacity)
            let currentCount = _storage.count
            _storage.copy(to: newStorage, count: currentCount)
            newStorage.header = currentCount.rawValue
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
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
        makeUnique()
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
        return _storage.read(at: .zero)
    }

    /// Replaces the priority element and returns the old value.
    @usableFromInline
    package mutating func replacePriority(with replacement: Element) -> Element {
        let removed = _storage.read(at: .zero)
        _storage.write(replacement, at: .zero)
        trickleDown(.zero)
        return removed
    }

    /// A read-only view into the underlying storage.
    ///
    /// The elements are in heap order, which is **not** sorted order.
    ///
    /// - Complexity: O(n) to copy elements.
    @inlinable
    public var unordered: [Element] {
        var result: [Element] = []
        result.reserveCapacity(_storage.header)
        (0..<_storage.count).forEach { index in
            result.append(_storage.read(at: index))
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
    public func element(at index: Heap<Element>.Index) -> Element? {
        guard isValid(index) else { return nil }
        return _storage.read(at: index)
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
        makeUnique()
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
            makeUnique()
            return removePriority()
        }
    }
}

// MARK: - Equatable (Copyable only)

extension Heap: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        guard lhs.order == rhs.order else { return false }
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

extension Heap: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        hasher.combine(order)
        (0..<_storage.count).forEach { index in
            hasher.combine(_storage.read(at: index))
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

    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Heap<Element>.Storage

        @usableFromInline
        let _end: Heap<Element>.Index.Count

        @usableFromInline
        var _index: Heap<Element>.Index = .zero

        @usableFromInline
        init(_storage: Heap<Element>.Storage) {
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
