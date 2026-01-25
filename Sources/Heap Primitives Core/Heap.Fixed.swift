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

// MARK: - Properties

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _storage.header == capacity }
}

// MARK: - Internal Heap Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func _insert(_ element: consuming Element) {
        let index = _storage.header
        _storage._initializeElement(at: index, to: element)
        _storage.header += 1
        _bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func _removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage._moveElement(at: 0)
        }

        let lastIndex = _storage.header - 1
        _swapElements(at: 0, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)
        _trickleDown(0)
        return removed
    }

    /// Swaps elements at two indices using the cached pointer.
    @usableFromInline
    package mutating func _swapElements(at i: Int, _ j: Int) {
        let ptr = _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func _bubbleUp(_ index: Int) {
        guard index > 0 else { return }

        var current = index
        let ptr = _cachedPtr

        switch order {
        case .ascending:
            while current > 0 {
                let parentIndex = (current - 1) / 2
                if unsafe ptr[current] < ptr[parentIndex] {
                    _swapElements(at: current, parentIndex)
                    current = parentIndex
                } else {
                    break
                }
            }
        case .descending:
            while current > 0 {
                let parentIndex = (current - 1) / 2
                if unsafe ptr[parentIndex] < ptr[current] {
                    _swapElements(at: current, parentIndex)
                    current = parentIndex
                } else {
                    break
                }
            }
        }
    }
}

// MARK: - Trickle Down (Single-Ended Heap)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    @usableFromInline
    package mutating func _trickleDown(_ startIndex: Int) {
        var current = startIndex
        let count = _storage.header
        let ptr = _cachedPtr

        switch order {
        case .ascending:
            while true {
                let leftChild = 2 * current + 1
                guard leftChild < count else { break }

                let rightChild = leftChild + 1
                var smallest = current

                if unsafe ptr[leftChild] < ptr[smallest] {
                    smallest = leftChild
                }
                if rightChild < count {
                    if unsafe ptr[rightChild] < ptr[smallest] {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                _swapElements(at: current, smallest)
                current = smallest
            }

        case .descending:
            while true {
                let leftChild = 2 * current + 1
                guard leftChild < count else { break }

                let rightChild = leftChild + 1
                var largest = current

                if unsafe ptr[largest] < ptr[leftChild] {
                    largest = leftChild
                }
                if rightChild < count {
                    if unsafe ptr[largest] < ptr[rightChild] {
                        largest = rightChild
                    }
                }

                if largest == current { break }

                _swapElements(at: current, largest)
                current = largest
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func _heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        var i = count / 2 - 1
        while i >= 0 {
            _trickleDown(i)
            i -= 1
        }
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Pushes an element onto the heap.
    ///
    /// Returns an ``Outcome`` indicating whether the element was inserted
    /// or returned due to overflow.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: consuming Element) -> Heap.Push.Outcome {
        guard _storage.header < capacity else {
            return .overflow(element)
        }
        _insert(element)
        return .inserted
    }

    /// Takes and returns the priority element, or nil if empty.
    ///
    /// - Returns: The priority element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        mutating get {
            _removePriority()
        }
    }

    /// Pops and returns the priority element.
    ///
    /// - Returns: The priority element.
    /// - Throws: ``Fixed/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Fixed.Error) -> Element {
        guard let element = _removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        let count = _storage.header
        if count > 0 {
            _storage._deinitializeElements(in: 0..<count)
        }
        _storage.header = 0
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
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `take`.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let ptr = _cachedPtr
        for i in 0..<count {
            body(unsafe ptr[i])
        }
    }
}

// MARK: - Index Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns the index of the root element, or nil if the heap is empty.
    @inlinable
    public func rootIndex() -> Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Returns whether the given index represents a valid position in the heap.
    @inlinable
    public func isValid(_ index: Heap<Element>.Index) -> Bool {
        index >= .zero && index.position.rawValue < count
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: capacity)
            let currentCount = _storage.header
            _storage._copyAllElements(to: newStorage, count: currentCount)
            newStorage.header = currentCount
            _storage = newStorage
            _cachedPtr = _storage._elementsPointer
        }
    }

    /// Pushes an element onto the heap (CoW-aware).
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: Element) -> Heap.Push.Outcome {
        _makeUnique()
        guard _storage.header < capacity else {
            return .overflow(element)
        }
        _insert(element)
        return .inserted
    }

    /// Takes and returns the priority element, or nil if empty (CoW-aware).
    @inlinable
    public var take: Element? {
        mutating get {
            _makeUnique()
            return _removePriority()
        }
    }

    /// Pops and returns the priority element (CoW-aware).
    @inlinable
    public mutating func pop() throws(__Heap.Fixed.Error) -> Element {
        _makeUnique()
        guard let element = _removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap (CoW-aware).
    @inlinable
    public mutating func clear() {
        _makeUnique()
        let count = _storage.header
        if count > 0 {
            _storage._deinitializeElements(in: 0..<count)
        }
        _storage.header = 0
    }
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
        return _storage._readElement(at: 0)
    }

    /// Returns the element at the given typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Heap<Element>.Index) -> Element? {
        guard isValid(index) else { return nil }
        return _storage._readElement(at: index.position.rawValue)
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Creates a fixed heap from a sequence.
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - capacity: Maximum number of elements. Must be non-negative.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
    /// - Note: If elements exceeds capacity, only the first `capacity` elements are kept.
    /// - Complexity: O(n)
    @inlinable
    public init(
        _ elements: some Swift.Sequence<Element>,
        capacity: Int,
        order: Heap<Element>.Order = .ascending
    ) throws(__Heap.Fixed.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        self._storage = Heap<Element>.Storage.create(minimumCapacity: capacity)
        self._cachedPtr = _storage._elementsPointer
        self.capacity = capacity
        self.order = order

        for element in elements {
            if _storage.header >= capacity { break }
            _storage._initializeElement(at: _storage.header, to: element)
            _storage.header += 1
        }

        if _storage.header > 1 {
            _heapify()
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
    public mutating func truncate(to newCount: Int) {
        let currentCount = _storage.header
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        _storage._deinitializeElements(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count (CoW-aware).
    @inlinable
    public mutating func truncate(to newCount: Int) {
        _makeUnique()
        let currentCount = _storage.header
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        _storage._deinitializeElements(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

// MARK: - Span Access

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// A read-only view of the heap's elements in heap order.
    ///
    /// Elements are in heap order, which is **not** sorted order.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            unsafe Span(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }

    /// A mutable view of the heap's elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    ///   After modification, you may need to re-heapify.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// A mutable view of the heap's elements (CoW-aware).
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            _makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}
