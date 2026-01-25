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

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func _ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header

        _storage._moveAllElements(to: newStorage, count: currentCount)
        newStorage.header = currentCount
        _storage.header = 0  // Prevent double-free

        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space to store the specified number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        _ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Internal)

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Appends element without maintaining heap property (for bulk init).
    @usableFromInline
    package mutating func _appendWithoutHeapify(_ element: consuming Element) {
        _ensureCapacity(_storage.header + 1)
        let index = _storage.header
        _storage._initializeElement(at: index, to: element)
        _storage.header += 1
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func _insert(_ element: consuming Element) {
        _ensureCapacity(_storage.header + 1)
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
        let ptr = unsafe _cachedPtr
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
        let ptr = unsafe _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// MARK: - Public Mutating Operations

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func push(_ element: consuming Element) {
        _insert(element)
    }

    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        let currentCount = _storage.header
        if currentCount > 0 {
            _storage._deinitializeElements(in: 0..<currentCount)
        }
        _storage.header = 0

        if !keepingCapacity {
            _storage = Heap<Element>.Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
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

        let ptr = unsafe _cachedPtr
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
        let ptr = unsafe _cachedPtr
        for i in 0..<count {
            body(unsafe ptr[i])
        }
    }
}

// MARK: - Index Operations

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns the index of the root element, or nil if the heap is empty.
    ///
    /// - Returns: Index of root element (position 0), or `nil` if empty.
    @inlinable
    public func rootIndex() -> Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Returns the index of the parent of the element at the given index.
    ///
    /// - Parameter index: The index of the child element.
    /// - Returns: Index of the parent, or `nil` if the index is the root.
    @inlinable
    public func parentIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        guard index.position > 0 else { return nil }
        return try? Heap<Element>.Index((index.position.rawValue - 1) / 2)
    }

    /// Returns the index of the left child of the element at the given index.
    ///
    /// - Parameter index: The index of the parent element.
    /// - Returns: Index of the left child, or `nil` if no left child exists.
    @inlinable
    public func leftChildIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        let childPosition = 2 * index.position.rawValue + 1
        guard childPosition < count else { return nil }
        return try? Heap<Element>.Index(childPosition)
    }

    /// Returns the index of the right child of the element at the given index.
    ///
    /// - Parameter index: The index of the parent element.
    /// - Returns: Index of the right child, or `nil` if no right child exists.
    @inlinable
    public func rightChildIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        let childPosition = 2 * index.position.rawValue + 2
        guard childPosition < count else { return nil }
        return try? Heap<Element>.Index(childPosition)
    }

    /// Returns whether the given index represents a valid position in the heap.
    ///
    /// - Parameter index: The index to validate.
    /// - Returns: `true` if the index is within bounds.
    @inlinable
    public func isValid(_ index: Heap<Element>.Index) -> Bool {
        index >= .zero && index.position.rawValue < count
    }
}
