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

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
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

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
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
        _bubbleUp(index)
    }

    /// Removes and returns the priority element (min for ascending, max for descending).
    @usableFromInline
    package mutating func _removePriority() -> Element? {
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
        _trickleDown(0)
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

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    ///
    /// For ascending order (min-heap): element bubbles up while smaller than parent.
    /// For descending order (max-heap): element bubbles up while larger than parent.
    @usableFromInline
    package mutating func _bubbleUp(_ index: Int) {
        guard index > 0 else { return }

        var current = index
        let ptr = unsafe _cachedPtr

        switch order {
        case .ascending:
            // Min-heap: bubble up while element < parent
            while current > 0 {
                let parentIndex = (current - 1) / 2
                // If current < parent, swap
                if unsafe ptr[current] < ptr[parentIndex] {
                    _swapElements(at: current, parentIndex)
                    current = parentIndex
                } else {
                    break
                }
            }
        case .descending:
            // Max-heap: bubble up while element > parent
            while current > 0 {
                let parentIndex = (current - 1) / 2
                // If current > parent (parent < current), swap
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

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    ///
    /// For ascending order (min-heap): element trickles down to larger of children.
    /// For descending order (max-heap): element trickles down to smaller of children.
    @usableFromInline
    package mutating func _trickleDown(_ startIndex: Int) {
        var current = startIndex
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        switch order {
        case .ascending:
            // Min-heap: trickle down, swapping with smaller child
            while true {
                let leftChild = 2 * current + 1
                guard leftChild < count else { break }

                let rightChild = leftChild + 1
                var smallest = current

                // Find smallest among current and children
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
            // Max-heap: trickle down, swapping with larger child
            while true {
                let leftChild = 2 * current + 1
                guard leftChild < count else { break }

                let rightChild = leftChild + 1
                var largest = current

                // Find largest among current and children
                // Using < operator: if largest < leftChild, then leftChild is larger
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

// MARK: - Heapify (Floyd's Algorithm)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func _heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        // Start from the last non-leaf node and trickle down
        var i = count / 2 - 1
        while i >= 0 {
            _trickleDown(i)
            i -= 1
        }
    }
}

// MARK: - Public Mutating Operations

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
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

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element (root).
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
        let ptr = unsafe _cachedPtr
        for i in 0..<count {
            body(unsafe ptr[i])
        }
    }
}

// MARK: - Index Operations

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
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
