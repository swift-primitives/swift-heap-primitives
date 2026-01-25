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

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _count == capacity }
}

// MARK: - Internal Heap Operations

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func _insert(_ element: consuming Element) {
        let index = _count
        unsafe _pointerToElement(at: index).initialize(to: element)
        _count += 1
        _bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func _removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            return unsafe _pointerToElement(at: 0).move()
        }

        let lastIndex = _count - 1
        _swapElements(at: 0, lastIndex)
        _count -= 1
        let removed = unsafe _pointerToElement(at: lastIndex).move()
        _trickleDown(0)
        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package mutating func _swapElements(at i: Int, _ j: Int) {
        let ptrI = unsafe _pointerToElement(at: i)
        let ptrJ = unsafe _pointerToElement(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func _bubbleUp(_ index: Int) {
        guard index > 0 else { return }

        var current = index

        switch order {
        case .ascending:
            while current > 0 {
                let parentIndex = (current &- 1) / 2
                if unsafe _readPointerToElement(at: current).pointee < _readPointerToElement(at: parentIndex).pointee {
                    _swapElements(at: current, parentIndex)
                    current = parentIndex
                } else {
                    break
                }
            }
        case .descending:
            while current > 0 {
                let parentIndex = (current &- 1) / 2
                if unsafe _readPointerToElement(at: parentIndex).pointee < _readPointerToElement(at: current).pointee {
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

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    @usableFromInline
    package mutating func _trickleDown(_ startIndex: Int) {
        var current = startIndex

        switch order {
        case .ascending:
            while true {
                let leftChild = current &* 2 &+ 1
                guard leftChild < _count else { break }

                let rightChild = leftChild + 1
                var smallest = current

                if unsafe _readPointerToElement(at: leftChild).pointee < _readPointerToElement(at: smallest).pointee {
                    smallest = leftChild
                }
                if rightChild < _count {
                    if unsafe _readPointerToElement(at: rightChild).pointee < _readPointerToElement(at: smallest).pointee {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                _swapElements(at: current, smallest)
                current = smallest
            }

        case .descending:
            while true {
                let leftChild = current &* 2 &+ 1
                guard leftChild < _count else { break }

                let rightChild = leftChild + 1
                var largest = current

                if unsafe _readPointerToElement(at: largest).pointee < _readPointerToElement(at: leftChild).pointee {
                    largest = leftChild
                }
                if rightChild < _count {
                    if unsafe _readPointerToElement(at: largest).pointee < _readPointerToElement(at: rightChild).pointee {
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

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func _heapify() {
        guard _count > 1 else { return }

        var i = _count / 2 - 1
        while i >= 0 {
            _trickleDown(i)
            i -= 1
        }
    }
}

// MARK: - Core Operations

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
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
    public mutating func push(_ element: consuming Element) -> Push.Outcome {
        guard _count < capacity else {
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
    /// - Throws: ``Static/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Static.Error) -> Element {
        guard let element = _removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the priority element.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return unsafe body(_readPointerToElement(at: 0).pointee)
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
        for i in 0..<count {
            body(unsafe _readPointerToElement(at: i).pointee)
        }
    }
}

// MARK: - Index Operations

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns the index of the root element, or nil if the heap is empty.
    @inlinable
    public func rootIndex() -> Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Returns whether the given index represents a valid position in the heap.
    @inlinable
    public func isValid(_ index: Heap<Element>.Index) -> Bool {
        index >= .zero && index.position.rawValue < _count
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Static where Element: Copyable & Comparison.`Protocol` {
    /// Returns the priority element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the priority element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !isEmpty else { return nil }
        return unsafe _readPointerToElement(at: 0).pointee
    }
}

// MARK: - Truncate

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        guard newCount < _count else { return }
        let targetCount = Swift.max(0, newCount)

        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in targetCount..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = targetCount
    }
}
