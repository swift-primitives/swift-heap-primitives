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

// MARK: - Property Typealias

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Shorthand for `Property_Primitives.Property<Tag, Heap<Element>.Binary>`.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>.Binary>
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Creates a heap from a sequence using O(n) heapification.
    ///
    /// - Parameter elements: The sequence of elements.
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>) {
        self._storage = Heap<Element>.Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)

        for element in elements {
            _appendWithoutHeapify(element)
        }

        if _storage.header > 1 {
            _heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: _storage.capacity)
            let currentCount = _storage.header
            _storage._copyAllElements(to: newStorage, count: currentCount)
            newStorage.header = currentCount
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }
}

// MARK: - CoW-aware Public Operations (Copyable only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap (CoW-aware).
    ///
    /// This method shadows the base `push(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func push(_ element: Element) {
        _makeUnique()
        _insert(element)
    }
}

// MARK: - Peek/Read Operations (Copyable only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Returns the minimum element without removing it.
    @usableFromInline
    package func _peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage._readElement(at: 0)
    }

    /// Returns the maximum element without removing it.
    @usableFromInline
    package func _peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage._readElement(at: 0) }
        if count == 2 { return _storage._readElement(at: 1) }
        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        return e1 < e2 ? e2 : e1
    }

    /// Replaces the minimum and returns the old value.
    @usableFromInline
    package mutating func _replaceMin(with replacement: Element) -> Element {
        let removed = _storage._readElement(at: 0)
        _storage._writeElement(at: 0, replacement)
        _trickleDownMin(Heap<Element>.Node.root)
        return removed
    }

    /// Replaces the maximum and returns the old value.
    @usableFromInline
    package mutating func _replaceMax(with replacement: Element) -> Element {
        if count == 1 {
            let removed = _storage._readElement(at: 0)
            _storage._writeElement(at: 0, replacement)
            return removed
        }

        if count == 2 {
            let removed = _storage._readElement(at: 1)
            _storage._writeElement(at: 1, replacement)
            _bubbleUp(Heap<Element>.Node.leftMax)
            return removed
        }

        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        let maxIndex = e1 < e2 ? 2 : 1
        let removed = _storage._readElement(at: maxIndex)
        _storage._writeElement(at: maxIndex, replacement)
        let maxNode = Heap<Element>.Node(offset: maxIndex, level: 1)
        _bubbleUp(maxNode)
        _trickleDownMax(maxNode)
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
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(_storage._readElement(at: i))
        }
        return result
    }
}

// MARK: - Element Access via Index (Copyable only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Returns the element at the given typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Heap<Element>.Index) -> Element? {
        guard isValid(index) else { return nil }
        return _storage._readElement(at: index.position.rawValue)
    }
}

// MARK: - Equatable (Copyable only)

extension Heap.Binary: Equatable where Element: Equatable & Copyable {
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

extension Heap.Binary: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_storage._readElement(at: i))
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable only)

extension Heap.Binary: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Heap.Binary: CustomStringConvertible {
    public var description: String {
        "Heap.Binary(\(count) elements)"
    }
}
#endif

// MARK: - Peek Tag

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Phantom tag for peek operations.
    public enum Peek {}
}

// MARK: - Peek Accessor (Copyable elements only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Nested accessor for peek operations.
    ///
    /// ```swift
    /// let heap: Heap<Int>.Binary = [3, 1, 4, 1, 5]
    /// if let min = heap.peek.min { print(min) }  // 1
    /// if let max = heap.peek.max { print(max) }  // 5
    /// ```
    @inlinable
    public var peek: Property<Peek>.Typed<Element> {
        Property_Primitives.Property.Typed(self)
    }
}

// MARK: - Peek Operations

extension Property_Primitives.Property.Typed
where Tag == Heap<Element>.Binary.Peek, Base == Heap<Element>.Binary, Element: Copyable & Comparable {
    /// The minimum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        base._peekMin()
    }

    /// The maximum element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        base._peekMax()
    }
}

// MARK: - Pop Tag

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Phantom tag for pop operations.
    public enum Pop {}
}

// MARK: - Pop Accessor (Copyable elements only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Nested accessor for pop operations.
    ///
    /// ```swift
    /// var heap: Heap<Int>.Binary = [3, 1, 4, 1, 5]
    /// let min = try heap.pop.min()  // 1
    /// let max = try heap.pop.max()  // 5
    /// ```
    @inlinable
    public var pop: Property<Pop> {
        _read {
            yield Property(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Pop> = Property(self)
            self = Heap<Element>.Binary()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Pop Operations

extension Property_Primitives.Property {
    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: `Heap.Binary.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min<E: Copyable & Comparable>() throws(Heap<E>.Binary.Error) -> E
    where Tag == Heap<E>.Binary.Pop, Base == Heap<E>.Binary {
        guard let element = base._removeMin() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: `Heap.Binary.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max<E: Copyable & Comparable>() throws(Heap<E>.Binary.Error) -> E
    where Tag == Heap<E>.Binary.Pop, Base == Heap<E>.Binary {
        guard let element = base._removeMax() else {
            throw .empty
        }
        return element
    }
}

// MARK: - Take Tag

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Phantom tag for take (optional removal) operations.
    public enum Take {}
}

// MARK: - Take Accessor (Copyable elements only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Nested accessor for optional removal operations.
    ///
    /// Use `take` when empty is a normal state (priority queue drain):
    /// ```swift
    /// var heap: Heap<Int>.Binary = [3, 1, 4, 1, 5]
    /// while let min = heap.take.min {
    ///     process(min)
    /// }
    /// ```
    @inlinable
    public var take: Property<Take>.Typed<Element> {
        _read {
            yield Property.Typed(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Take>.Typed<Element> = Property.Typed(self)
            self = Heap<Element>.Binary()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Take Operations

extension Property_Primitives.Property.Typed
where Tag == Heap<Element>.Binary.Take, Base == Heap<Element>.Binary, Element: Copyable & Comparable {
    /// Removes and returns the minimum element, or `nil` if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var min: Element? {
        mutating get {
            base._removeMin()
        }
    }

    /// Removes and returns the maximum element, or `nil` if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var max: Element? {
        mutating get {
            base._removeMax()
        }
    }
}

// MARK: - Push Tag

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Phantom tag for push operations.
    public enum Push {}
}

// MARK: - Push Accessor (Copyable elements only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Nested accessor for push operations.
    ///
    /// ```swift
    /// var heap = Heap<Int>.Binary()
    /// heap.push(42)                    // single element
    /// heap.push.contentsOf([1, 2, 3])  // bulk insert
    /// ```
    @inlinable
    public var push: Property<Push> {
        _read {
            yield Property(self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var property: Property<Push> = Property(self)
            self = Heap<Element>.Binary()  // Clear self to release our reference
            defer { self = property.base }
            yield &property
        }
    }
}

// MARK: - Push Operations

extension Property_Primitives.Property {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func callAsFunction<E: Copyable & Comparable>(_ element: E)
    where Tag == Heap<E>.Binary.Push, Base == Heap<E>.Binary {
        base._insert(element)
    }

    /// Inserts multiple elements into the heap.
    ///
    /// Uses a heuristic to choose between per-element insertion
    /// and full re-heapification for optimal performance.
    ///
    /// - Parameter elements: The elements to insert.
    /// - Complexity: O(n + k) where k is the number of new elements.
    @inlinable
    public mutating func contentsOf<E: Copyable & Comparable>(_ elements: some Swift.Sequence<E>)
    where Tag == Heap<E>.Binary.Push, Base == Heap<E>.Binary {
        let origCount = base.count
        for element in elements {
            base._appendWithoutHeapify(element)
        }
        let newCount = base.count

        guard newCount > origCount, newCount > 1 else { return }

        // Heuristic: use Floyd's if k > 2n / log(n)
        let heuristicLimit = 2 * newCount / Swift.max(1, newCount._binaryLogarithm())
        let useFloyd = (newCount - origCount) > heuristicLimit

        if useFloyd {
            base._heapify()
        } else {
            for offset in origCount..<newCount {
                base._bubbleUp(Heap<E>.Node(offset: offset))
            }
        }
    }
}

// MARK: - Replace Accessor (Copyable elements only)

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Nested accessor for replace operations.
    ///
    /// Replace is more efficient than pop + push when you need to
    /// replace the extremum:
    /// ```swift
    /// var heap: Heap<Int>.Binary = [3, 1, 4, 1, 5]
    /// let oldMin = try heap.replace.min(with: 0)  // returns 1, heap now has 0
    /// let oldMax = try heap.replace.max(with: 9)  // returns 5, heap now has 9
    /// ```
    @inlinable
    public var replace: Replace {
        _read {
            yield Replace(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Replace(heap: self)
            self = Heap<Element>.Binary()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Replace Type

extension Heap.Binary where Element: Copyable & Comparison.`Protocol` {
    /// Namespace for replace operations.
    public struct Replace {
        @usableFromInline
        var heap: Heap<Element>.Binary

        @usableFromInline
        init(heap: Heap<Element>.Binary) {
            self.heap = heap
        }
    }
}

// MARK: - Replace Operations

extension Heap.Binary.Replace where Element: Copyable {
    /// Replaces the minimum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original minimum element.
    /// - Throws: `Heap.Binary.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min(with replacement: Element) throws(Heap<Element>.Binary.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty
        }
        return heap._replaceMin(with: replacement)
    }

    /// Replaces the maximum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original maximum element.
    /// - Throws: `Heap.Binary.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max(with replacement: Element) throws(Heap<Element>.Binary.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty
        }
        return heap._replaceMax(with: replacement)
    }
}

// MARK: - Sequence Conformance (Copyable only) for Fixed

extension Heap.Fixed: Swift.Sequence where Element: Copyable {

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
