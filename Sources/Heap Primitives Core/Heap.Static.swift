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

public import Range_Primitives

// MARK: - Properties

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { count.rawValue == capacity }
}

// MARK: - Index Navigation

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns the index of the parent of the element at the given index.
    @inlinable
    package func parentIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        guard index.position > 0 else { return nil }
        return try? Heap<Element>.Index((index.position.rawValue - 1) / 2)
    }

    /// Returns the index of the left child of the element at the given index.
    @inlinable
    package func leftChildIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        let childPosition = 2 * index.position.rawValue + 1
        guard childPosition < count.rawValue else { return nil }
        return try? Heap<Element>.Index(childPosition)
    }

    /// Returns the index of the right child of the element at the given index.
    @inlinable
    package func rightChildIndex(of index: Heap<Element>.Index) -> Heap<Element>.Index? {
        let childPosition = 2 * index.position.rawValue + 2
        guard childPosition < count.rawValue else { return nil }
        return try? Heap<Element>.Index(childPosition)
    }
}

// MARK: - Internal Heap Operations

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let index = Heap<Element>.Index(__unchecked: (), position: count.rawValue)
        inline.initialize(to: element, at: index)
        count = Heap<Element>.Index.Count(__unchecked: count.rawValue + 1)
        bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard count > .zero else { return nil }

        if count.rawValue == 1 {
            count = .zero
            return inline.move(at: .zero)
        }

        let lastIndex = Heap<Element>.Index(__unchecked: (), position: count.rawValue - 1)
        swapElements(at: .zero, lastIndex)
        count = Heap<Element>.Index.Count(__unchecked: count.rawValue - 1)
        let removed = inline.move(at: lastIndex)
        trickleDown(.zero)
        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package mutating func swapElements(at i: Heap<Element>.Index, _ j: Heap<Element>.Index) {
        let ptrI = unsafe inline.pointer(at: i)
        let ptrJ = unsafe inline.pointer(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func bubbleUp(_ index: Heap<Element>.Index) {
        var current = index

        switch order {
        case .ascending:
            while let parent = parentIndex(of: current) {
                if unsafe inline.read(at: current).pointee < inline.read(at: parent).pointee {
                    swapElements(at: current, parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = parentIndex(of: current) {
                if unsafe inline.read(at: parent).pointee < inline.read(at: current).pointee {
                    swapElements(at: current, parent)
                    current = parent
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
    package mutating func trickleDown(_ startIndex: Heap<Element>.Index) {
        var current = startIndex

        switch order {
        case .ascending:
            while let leftChild = leftChildIndex(of: current) {
                var smallest = current

                if unsafe inline.read(at: leftChild).pointee < inline.read(at: smallest).pointee {
                    smallest = leftChild
                }
                if let rightChild = rightChildIndex(of: current) {
                    if unsafe inline.read(at: rightChild).pointee < inline.read(at: smallest).pointee {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                swapElements(at: current, smallest)
                current = smallest
            }

        case .descending:
            while let leftChild = leftChildIndex(of: current) {
                var largest = current

                if unsafe inline.read(at: largest).pointee < inline.read(at: leftChild).pointee {
                    largest = leftChild
                }
                if let rightChild = rightChildIndex(of: current) {
                    if unsafe inline.read(at: largest).pointee < inline.read(at: rightChild).pointee {
                        largest = rightChild
                    }
                }

                if largest == current { break }

                swapElements(at: current, largest)
                current = largest
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Static where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let countValue = count.rawValue
        guard countValue > 1 else { return }

        var position = countValue / 2 - 1
        while position >= 0 {
            let index = Heap<Element>.Index(__unchecked: (), position: position)
            trickleDown(index)
            position -= 1
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
        guard count.rawValue < capacity else {
            return .overflow(element)
        }
        insert(element)
        return .inserted
    }

    /// Takes and returns the priority element, or nil if empty.
    ///
    /// - Returns: The priority element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        mutating get {
            removePriority()
        }
    }

    /// Pops and returns the priority element.
    ///
    /// - Returns: The priority element.
    /// - Throws: ``Static/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Static.Error) -> Element {
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        inline.deinitialize(count: count)
        count = .zero
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
        guard count > .zero else { return nil }
        return unsafe body(inline.read(at: .zero).pointee)
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
        (0..<count).forEach { index in
            body(unsafe inline.read(at: index).pointee)
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
        index >= .zero && index.position.rawValue < count.rawValue
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
        return unsafe inline.read(at: .zero).pointee
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
        guard newCount < count.rawValue else { return }
        let targetCount = Swift.max(0, newCount)
        let targetCountTyped = Heap<Element>.Index.Count(__unchecked: targetCount)

        // Use Int..<Count pattern for Range.Lazy creation
        inline.deinitialize(in: targetCount..<count)
        count = targetCountTyped
    }
}
