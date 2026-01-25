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
        _bubbleUp(Heap<Element>.Node(offset: index))
    }

    /// Removes and returns the minimum element.
    @usableFromInline
    package mutating func _removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage._moveElement(at: 0)
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _storage.header - 1
        _swapElements(at: 0, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)
        _trickleDownMin(Heap<Element>.Node.root)
        return removed
    }

    /// Removes and returns the maximum element.
    @usableFromInline
    package mutating func _removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage._moveElement(at: 0)
        }

        if count == 2 {
            _storage.header = 1
            return _storage._moveElement(at: 1)
        }

        // Find max (at index 1 or 2) using < operator
        let ptr = _cachedPtr
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1

        // Swap with last, remove last, trickle down
        let lastIndex = _storage.header - 1
        _swapElements(at: maxIndex, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)

        if maxIndex < _storage.header {
            _trickleDownMax(Heap<Element>.Node(offset: maxIndex, level: 1))
        }

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

// MARK: - Bubble Up

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func _bubbleUp(_ node: Heap<Element>.Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let ptr = _cachedPtr

        let nodeIsLess = unsafe ptr[node.offset] < ptr[parent.offset]
        let parentIsLess = unsafe ptr[parent.offset] < ptr[node.offset]

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            _swapElements(at: node.offset, parent.offset)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = unsafe ptr[grandparent.offset] < ptr[node.offset]
                guard !gpIsLess else { break }
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = unsafe ptr[node.offset] < ptr[grandparent.offset]
                guard !nodeIsLessGp else { break }
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    package mutating func _trickleDownMin(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var smallest = node
            var smallestOffset = node.offset

            let rightChild = node.rightChild()

            if unsafe ptr[leftChild.offset] < ptr[smallestOffset] {
                smallest = leftChild
                smallestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[rightChild.offset] < ptr[smallestOffset] {
                    smallest = rightChild
                    smallestOffset = rightChild.offset
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[gcOffset] < ptr[smallestOffset] {
                    smallest = Heap<Element>.Node(offset: gcOffset, level: gc0.level)
                    smallestOffset = gcOffset
                }
            }

            if smallest.offset == node.offset { break }

            _swapElements(at: node.offset, smallest.offset)

            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if unsafe ptr[parent.offset] < ptr[smallest.offset] {
                    _swapElements(at: smallest.offset, parent.offset)
                }
                node = smallest
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    package mutating func _trickleDownMax(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var largest = node
            var largestOffset = node.offset

            let rightChild = node.rightChild()

            if unsafe ptr[largestOffset] < ptr[leftChild.offset] {
                largest = leftChild
                largestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[largestOffset] < ptr[rightChild.offset] {
                    largest = rightChild
                    largestOffset = rightChild.offset
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[largestOffset] < ptr[gcOffset] {
                    largest = Heap<Element>.Node(offset: gcOffset, level: gc0.level)
                    largestOffset = gcOffset
                }
            }

            if largest.offset == node.offset { break }

            _swapElements(at: node.offset, largest.offset)

            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                if unsafe ptr[largest.offset] < ptr[parent.offset] {
                    _swapElements(at: largest.offset, parent.offset)
                }
                node = largest
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    package mutating func _heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        let limit = count / 2

        var level = Heap<Element>.Node.level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = Heap<Element>.Node.firstNode(onLevel: level)
            let lastOnLevel = Heap<Element>.Node.lastNode(onLevel: level)

            let startOffset = firstOnLevel.offset
            let endOffset = Swift.min(lastOnLevel.offset, limit - 1)

            if Heap<Element>.Node.isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(Heap<Element>.Node(offset: offset, level: level))
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(Heap<Element>.Node(offset: offset, level: level))
                }
            }
            level -= 1
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

    /// Takes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMin() -> Element? {
        _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMax() -> Element? {
        _removeMax()
    }

    /// Pops and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Fixed/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMin() throws(__Heap.Fixed.Error) -> Element {
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Fixed/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMax() throws(__Heap.Fixed.Error) -> Element {
        guard let element = _removeMax() else {
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
    /// Provides borrowing access to the minimum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the minimum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
    }

    /// Provides borrowing access to the maximum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the maximum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return body(unsafe _cachedPtr[0]) }
        if count == 2 { return body(unsafe _cachedPtr[1]) }

        let ptr = _cachedPtr
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1
        return body(unsafe ptr[maxIndex])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
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

    /// Takes and returns the minimum element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func takeMin() -> Element? {
        _makeUnique()
        return _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func takeMax() -> Element? {
        _makeUnique()
        return _removeMax()
    }

    /// Pops and returns the minimum element (CoW-aware).
    @inlinable
    public mutating func popMin() throws(__Heap.Fixed.Error) -> Element {
        _makeUnique()
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element (CoW-aware).
    @inlinable
    public mutating func popMax() throws(__Heap.Fixed.Error) -> Element {
        _makeUnique()
        guard let element = _removeMax() else {
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
    /// Returns the minimum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage._readElement(at: 0)
    }

    /// Returns the maximum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage._readElement(at: 0) }
        if count == 2 { return _storage._readElement(at: 1) }
        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        return e1 < e2 ? e2 : e1
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
    /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
    /// - Note: If elements exceeds capacity, only the first `capacity` elements are kept.
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>, capacity: Int) throws(__Heap.Fixed.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        self._storage = Heap<Element>.Storage.create(minimumCapacity: capacity)
        self._cachedPtr = _storage._elementsPointer
        self.capacity = capacity

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
