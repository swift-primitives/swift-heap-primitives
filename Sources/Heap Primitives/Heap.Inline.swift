// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Note: Heap.Inline is declared INSIDE the Heap struct body (in Heap.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Heap.Inline.

// MARK: - Properties

extension Heap.Inline where Element: ~Copyable {
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

// Note: Push.Outcome is declared in Heap.swift struct body per MEM-COPY-006

// MARK: - Internal Heap Operations

extension Heap.Inline where Element: ~Copyable {
    /// Inserts an element and restores heap property.
    @usableFromInline
    mutating func _insert(_ element: consuming Element) {
        let index = _count
        unsafe _pointerToElement(at: index).initialize(to: element)
        _count += 1
        _bubbleUp(index)
    }

    /// Removes and returns the minimum element.
    @usableFromInline
    mutating func _removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            return unsafe _pointerToElement(at: 0).move()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: 0, lastIndex)
        _count -= 1
        let removed = unsafe _pointerToElement(at: lastIndex).move()
        _trickleDownMin(0)
        return removed
    }

    /// Removes and returns the maximum element.
    @usableFromInline
    mutating func _removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            return unsafe _pointerToElement(at: 0).move()
        }

        if count == 2 {
            _count = 1
            return unsafe _pointerToElement(at: 1).move()
        }

        // Find max (at index 1 or 2) using isLessThan
        let maxIndex: Int
        if Element.isLessThan(
            unsafe _readPointerToElement(at: 1).pointee,
            unsafe _readPointerToElement(at: 2).pointee
        ) {
            maxIndex = 2
        } else {
            maxIndex = 1
        }

        // Swap with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: maxIndex, lastIndex)
        _count -= 1
        let removed = unsafe _pointerToElement(at: lastIndex).move()

        if maxIndex < _count {
            _trickleDownMax(maxIndex, level: 1)
        }

        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    mutating func _swapElements(at i: Int, _ j: Int) {
        let ptrI = unsafe _pointerToElement(at: i)
        let ptrJ = unsafe _pointerToElement(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Level Calculations

extension Heap.Inline where Element: ~Copyable {
    /// Computes the level for a given offset.
    @usableFromInline
    static func _level(forOffset offset: Int) -> Int {
        (offset &+ 1)._binaryLogarithm()
    }

    /// Whether a level is a min level (even: 0, 2, 4, ...).
    @usableFromInline
    static func _isMinLevel(_ level: Int) -> Bool {
        level & 0b1 == 0
    }
}

// MARK: - Bubble Up

extension Heap.Inline where Element: ~Copyable {
    /// Restores heap property by moving element up.
    @usableFromInline
    mutating func _bubbleUp(_ nodeOffset: Int) {
        guard nodeOffset > 0 else { return }

        let parentOffset = (nodeOffset &- 1) / 2
        var nodeOffset = nodeOffset
        var level = Self._level(forOffset: nodeOffset)

        let nodeIsLess = Element.isLessThan(
            unsafe _readPointerToElement(at: nodeOffset).pointee,
            unsafe _readPointerToElement(at: parentOffset).pointee
        )
        let parentIsLess = Element.isLessThan(
            unsafe _readPointerToElement(at: parentOffset).pointee,
            unsafe _readPointerToElement(at: nodeOffset).pointee
        )

        let isMinLevel = Self._isMinLevel(level)

        if (isMinLevel && parentIsLess) || (!isMinLevel && nodeIsLess) {
            _swapElements(at: nodeOffset, parentOffset)
            nodeOffset = parentOffset
            level -= 1
        }

        if Self._isMinLevel(level) {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let gpIsLess = Element.isLessThan(
                    unsafe _readPointerToElement(at: gpOffset).pointee,
                    unsafe _readPointerToElement(at: nodeOffset).pointee
                )
                guard !gpIsLess else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        } else {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let nodeIsLessGp = Element.isLessThan(
                    unsafe _readPointerToElement(at: nodeOffset).pointee,
                    unsafe _readPointerToElement(at: gpOffset).pointee
                )
                guard !nodeIsLessGp else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Inline where Element: ~Copyable {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMin(_ startOffset: Int) {
        var nodeOffset = startOffset
        var level = Self._level(forOffset: startOffset)

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var smallestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if Element.isLessThan(
                unsafe _readPointerToElement(at: leftChildOffset).pointee,
                unsafe _readPointerToElement(at: smallestOffset).pointee
            ) {
                smallestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: rightChildOffset).pointee,
                    unsafe _readPointerToElement(at: smallestOffset).pointee
                ) {
                    smallestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: gcOffset).pointee,
                    unsafe _readPointerToElement(at: smallestOffset).pointee
                ) {
                    smallestOffset = gcOffset
                }
            }

            if smallestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, smallestOffset)

            if smallestOffset >= gc0 {
                let parentOffset = (smallestOffset &- 1) / 2
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: parentOffset).pointee,
                    unsafe _readPointerToElement(at: smallestOffset).pointee
                ) {
                    _swapElements(at: smallestOffset, parentOffset)
                }
                nodeOffset = smallestOffset
                level += 2
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.Inline where Element: ~Copyable {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMax(_ startOffset: Int, level startLevel: Int) {
        var nodeOffset = startOffset
        var level = startLevel

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var largestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if Element.isLessThan(
                unsafe _readPointerToElement(at: largestOffset).pointee,
                unsafe _readPointerToElement(at: leftChildOffset).pointee
            ) {
                largestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: largestOffset).pointee,
                    unsafe _readPointerToElement(at: rightChildOffset).pointee
                ) {
                    largestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: largestOffset).pointee,
                    unsafe _readPointerToElement(at: gcOffset).pointee
                ) {
                    largestOffset = gcOffset
                }
            }

            if largestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, largestOffset)

            if largestOffset >= gc0 {
                let parentOffset = (largestOffset &- 1) / 2
                if Element.isLessThan(
                    unsafe _readPointerToElement(at: largestOffset).pointee,
                    unsafe _readPointerToElement(at: parentOffset).pointee
                ) {
                    _swapElements(at: largestOffset, parentOffset)
                }
                nodeOffset = largestOffset
                level += 2
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Inline where Element: ~Copyable {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    mutating func _heapify() {
        guard _count > 1 else { return }

        let limit = _count / 2

        var level = Self._level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = (1 &<< level) &- 1
            let lastOnLevel = (1 &<< (level &+ 1)) &- 2

            let startOffset = firstOnLevel
            let endOffset = Swift.min(lastOnLevel, limit - 1)

            if Self._isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(offset)
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(offset, level: level)
                }
            }
            level -= 1
        }
    }
}

// MARK: - Core Operations

extension Heap.Inline where Element: ~Copyable {
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
    /// - Throws: ``Heap/Inline/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMin() throws(__Heap.Inline.Error) -> Element {
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/Inline/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMax() throws(__Heap.Inline.Error) -> Element {
        guard let element = _removeMax() else {
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

extension Heap.Inline where Element: ~Copyable {
    /// Provides borrowing access to the minimum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the minimum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return unsafe body(_readPointerToElement(at: 0).pointee)
    }

    /// Provides borrowing access to the maximum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the maximum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return unsafe body(_readPointerToElement(at: 0).pointee) }
        if count == 2 { return unsafe body(_readPointerToElement(at: 1).pointee) }

        let e1IsLess = Element.isLessThan(
            unsafe _readPointerToElement(at: 1).pointee,
            unsafe _readPointerToElement(at: 2).pointee
        )
        let maxIndex = e1IsLess ? 2 : 1
        return unsafe body(_readPointerToElement(at: maxIndex).pointee)
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// This method is the primary iteration mechanism for `Heap.Inline` because
    /// `Sequence` conformance is disabled due to a Swift compiler bug. Use this
    /// instead of `for-in` loops:
    ///
    /// ```swift
    /// // Instead of: for element in heap { ... }
    /// heap.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
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

extension Heap.Inline where Element: Copyable {
    /// Returns the minimum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return unsafe _readPointerToElement(at: 0).pointee
    }

    /// Returns the maximum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return unsafe _readPointerToElement(at: 0).pointee }
        if count == 2 { return unsafe _readPointerToElement(at: 1).pointee }

        let e1 = unsafe _readPointerToElement(at: 1).pointee
        let e2 = unsafe _readPointerToElement(at: 2).pointee
        return Element.isLessThan(e1, e2) ? e2 : e1
    }
}

// MARK: - Truncate

extension Heap.Inline where Element: ~Copyable {
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
