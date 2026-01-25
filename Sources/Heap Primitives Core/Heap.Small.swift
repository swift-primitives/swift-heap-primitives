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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity (inline or heap).
    @inlinable
    public var capacity: Int {
        if let heap = _heap {
            return heap.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Internal Heap Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns a pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        if let heapPtr = unsafe _heapPtr {
            return unsafe heapPtr + index
        } else {
            return unsafe _inlinePointerToElement(at: index)
        }
    }

    /// Returns a read pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
        if let heapPtr = unsafe _heapPtr {
            return unsafe UnsafePointer(heapPtr + index)
        } else {
            return unsafe _inlineReadPointerToElement(at: index)
        }
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func _insert(_ element: consuming Element) {
        let index = _count
        unsafe _pointerToElement(at: index).initialize(to: element)
        _count += 1
        if _heap != nil {
            _heap!.header = _count
        }
        _bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func _removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            if _heap != nil {
                _heap!.header = 0
            }
            return unsafe _pointerToElement(at: 0).move()
        }

        let lastIndex = _count - 1
        _swapElements(at: 0, lastIndex)
        _count -= 1
        if _heap != nil {
            _heap!.header = _count
        }
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
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

// MARK: - Heap Growth

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Internal: push element to heap storage.
    @usableFromInline
    package mutating func _pushToHeap(_ element: consuming Element) {
        guard let heap = _heap, let _ = unsafe _heapPtr else {
            preconditionFailure("_pushToHeap called without heap storage")
        }

        if _count >= heap.capacity {
            _growHeap(minimumCapacity: _count + 1)
        }

        unsafe (_heapPtr! + _count).initialize(to: element)
        _count += 1
        heap.header = _count
        _bubbleUp(_count - 1)
    }

    /// Internal: grow heap storage.
    @usableFromInline
    package mutating func _growHeap(minimumCapacity: Int) {
        guard let oldStorage = _heap else {
            preconditionFailure("_growHeap called without heap storage")
        }

        let newCapacity = Swift.max(minimumCapacity, oldStorage.capacity * 2)
        let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)

        oldStorage._moveAllElements(to: newStorage, count: _count)
        newStorage.header = _count
        oldStorage.header = 0

        _heap = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }
}

// MARK: - Core Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Pushes an element onto the heap.
    ///
    /// If the heap exceeds inline capacity, elements are moved to heap storage.
    /// Push operations never fail - the heap grows automatically.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(log n) amortized, O(n) when spilling to heap.
    @inlinable
    public mutating func push(_ element: consuming Element) {
        if _heap != nil {
            _pushToHeap(element)
        } else if _count < inlineCapacity {
            _insert(element)
        } else {
            _spillToHeap(minimumCapacity: _count + 1)
            _pushToHeap(element)
        }
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
    /// - Throws: ``Small/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Small.Error) -> Element {
        guard let element = _removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// Does not shrink back to inline storage if spilled.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        guard _count > 0 else { return }

        if let heap = _heap {
            heap._deinitializeElements(in: 0..<_count)
            heap.header = 0
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
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

// MARK: - Peek (Copyable elements)

extension Heap.Small where Element: Copyable & Comparison.`Protocol` {
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
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

        if let heap = _heap {
            heap._deinitializeElements(in: targetCount..<_count)
            heap.header = targetCount
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in targetCount..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = targetCount
    }
}

// MARK: - Span Access

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Read-only span of the heap elements in heap order.
    ///
    /// Elements are in heap order, which is **not** sorted order.
    @inlinable
    public var span: Span<Element> {
        _read {
            if let heapPtr = unsafe _heapPtr {
                yield unsafe Span(_unsafeStart: heapPtr, count: _count)
            } else {
                yield unsafe Span(_unsafeStart: _inlineReadPointerToElement(at: 0), count: _count)
            }
        }
    }

    /// Mutable span of the heap elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        _read {
            if let heapPtr = unsafe _heapPtr {
                yield unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
            } else {
                let ptr = unsafe UnsafeMutablePointer(mutating: _inlineReadPointerToElement(at: 0))
                yield unsafe MutableSpan(_unsafeStart: ptr, count: _count)
            }
        }
        _modify {
            if let heapPtr = unsafe _heapPtr {
                var s = unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
                yield &s
            } else {
                var s = unsafe MutableSpan(_unsafeStart: _inlineMutableBasePointer(), count: _count)
                yield &s
            }
        }
    }

    /// Returns the mutable inline base pointer.
    @usableFromInline
    @unsafe
    package mutating func _inlineMutableBasePointer() -> UnsafeMutablePointer<Element> {
        unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            return unsafe basePtr.assumingMemoryBound(to: Element.self)
        }
    }
}
