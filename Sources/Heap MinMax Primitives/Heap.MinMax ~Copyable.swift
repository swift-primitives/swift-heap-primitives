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

public import Heap_Primitives_Core
public import Range_Primitives

// MARK: - Properties

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap<Element>.Index.Count { _storage.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func ensureCapacity(_ minimumCapacity: Heap<Element>.Index.Count) {
        guard _storage.capacity < minimumCapacity.rawValue else { return }

        let newCapacity = Swift.max(minimumCapacity.rawValue, _storage.capacity * 2, 4)
        let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.count

        _storage.move(to: newStorage, count: currentCount)
        newStorage.header = currentCount.rawValue
        _storage.header = 0

        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(Heap<Element>.Index.Count(__unchecked: minimumCapacity))
    }
}

// MARK: - Node (Level-Aware Navigation for MinMax Heap)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Internal node representation for min-max heap navigation.
    ///
    /// Uses raw Int offset for level computation (binary logarithm requires Int arithmetic).
    @usableFromInline
    package struct Node {
        @usableFromInline
        package var offset: Int

        @usableFromInline
        package var level: Int

        @inlinable
        package init(offset: Int, level: Int) {
            self.offset = offset
            self.level = level
        }

        @inlinable
        package init(offset: Int) {
            self.init(offset: offset, level: Self.level(forOffset: offset))
        }

        @inlinable
        package static func level(forOffset offset: Int) -> Int {
            (offset &+ 1)._binaryLogarithm()
        }

        @inlinable
        package static func isMinLevel(_ level: Int) -> Bool {
            level & 0b1 == 0
        }

        @inlinable
        package var isMinLevel: Bool {
            Self.isMinLevel(level)
        }

        @inlinable
        package var isRoot: Bool {
            offset == 0
        }

        @inlinable
        package static var root: Self {
            Self(offset: 0, level: 0)
        }

        @inlinable
        package static var leftMax: Self {
            Self(offset: 1, level: 1)
        }

        @inlinable
        package static var rightMax: Self {
            Self(offset: 2, level: 1)
        }

        @inlinable
        package static func firstNode(onLevel level: Int) -> Self {
            Self(offset: (1 &<< level) &- 1, level: level)
        }

        @inlinable
        package static func lastNode(onLevel level: Int) -> Self {
            Self(offset: (1 &<< (level &+ 1)) &- 2, level: level)
        }

        @inlinable
        package func parent() -> Self {
            Self(offset: (offset &- 1) / 2, level: level &- 1)
        }

        @inlinable
        package func grandParent() -> Self? {
            guard offset > 2 else { return nil }
            return Self(offset: (offset &- 3) / 4, level: level &- 2)
        }

        @inlinable
        package func leftChild() -> Self {
            Self(offset: offset &* 2 &+ 1, level: level &+ 1)
        }

        @inlinable
        package func rightChild() -> Self {
            Self(offset: offset &* 2 &+ 2, level: level &+ 1)
        }

        @inlinable
        package func firstGrandchild() -> Self {
            Self(offset: offset &* 4 &+ 3, level: level &+ 2)
        }

        /// Converts offset to typed Index.
        @inlinable
        package var index: Heap<Element>.Index {
            Heap<Element>.Index(__unchecked: (), position: offset)
        }
    }
}

extension Int {
    @usableFromInline
    package func _binaryLogarithm() -> Int {
        precondition(self > 0)
        return Int.bitWidth - 1 - self.leadingZeroBitCount
    }
}

// MARK: - Core Operations (Internal)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        let newCount = Heap<Element>.Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = Heap<Element>.Index(__unchecked: (), position: _storage.header)
        _storage.initialize(to: element, at: index)
        _storage.header += 1
    }

    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let newCount = Heap<Element>.Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = _storage.header
        let typedIndex = Heap<Element>.Index(__unchecked: (), position: index)
        _storage.initialize(to: element, at: typedIndex)
        _storage.header += 1
        bubbleUp(Node(offset: index))
    }

    @usableFromInline
    package mutating func removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage.move(at: .zero)
        }

        let lastIndex = _storage.header - 1
        swapElements(at: 0, lastIndex)
        _storage.header -= 1
        let lastTypedIndex = Heap<Element>.Index(__unchecked: (), position: lastIndex)
        let removed = _storage.move(at: lastTypedIndex)
        trickleDownMin(Node.root)
        return removed
    }

    @usableFromInline
    package mutating func removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage.move(at: .zero)
        }

        if count == 2 {
            _storage.header = 1
            let index = Heap<Element>.Index(__unchecked: (), position: 1)
            return _storage.move(at: index)
        }

        let ptr = unsafe _cachedPtr
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1

        let lastIndex = _storage.header - 1
        swapElements(at: maxIndex, lastIndex)
        _storage.header -= 1
        let lastTypedIndex = Heap<Element>.Index(__unchecked: (), position: lastIndex)
        let removed = _storage.move(at: lastTypedIndex)

        if maxIndex < _storage.header {
            trickleDownMax(Node(offset: maxIndex, level: 1))
        }

        return removed
    }

    /// Swaps elements at two node offsets using the cached pointer.
    @usableFromInline
    package mutating func swapElements(at i: Int, _ j: Int) {
        let ptr = unsafe _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// MARK: - Bubble Up (MinMax Heap)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func bubbleUp(_ node: Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let ptr = unsafe _cachedPtr

        let nodeIsLess = unsafe ptr[node.offset] < ptr[parent.offset]
        let parentIsLess = unsafe ptr[parent.offset] < ptr[node.offset]

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            swapElements(at: node.offset, parent.offset)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = unsafe ptr[grandparent.offset] < ptr[node.offset]
                guard !gpIsLess else { break }
                swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = unsafe ptr[node.offset] < ptr[grandparent.offset]
                guard !nodeIsLessGp else { break }
                swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func trickleDownMin(_ startNode: Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

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
                    smallest = Node(offset: gcOffset, level: gc0.level)
                    smallestOffset = gcOffset
                }
            }

            if smallest.offset == node.offset { break }

            swapElements(at: node.offset, smallest.offset)

            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if unsafe ptr[parent.offset] < ptr[smallest.offset] {
                    swapElements(at: smallest.offset, parent.offset)
                }
                node = smallest
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func trickleDownMax(_ startNode: Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

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
                    largest = Node(offset: gcOffset, level: gc0.level)
                    largestOffset = gcOffset
                }
            }

            if largest.offset == node.offset { break }

            swapElements(at: node.offset, largest.offset)

            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                if unsafe ptr[largest.offset] < ptr[parent.offset] {
                    swapElements(at: largest.offset, parent.offset)
                }
                node = largest
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify (Floyd's Algorithm for MinMax)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        let limit = count / 2

        var level = Node.level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = Node.firstNode(onLevel: level)
            let lastOnLevel = Node.lastNode(onLevel: level)

            let startOffset = firstOnLevel.offset
            let endOffset = Swift.min(lastOnLevel.offset, limit - 1)

            if Node.isMinLevel(level) {
                for offset in startOffset...endOffset {
                    trickleDownMin(Node(offset: offset, level: level))
                }
            } else {
                for offset in startOffset...endOffset {
                    trickleDownMax(Node(offset: offset, level: level))
                }
            }
            level -= 1
        }
    }
}

// MARK: - Public Mutating Operations

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap.
    @inlinable
    public mutating func push(_ element: consuming Element) {
        insert(element)
    }

    /// Removes all elements from the heap.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        let currentCount = _storage.count
        if currentCount > .zero {
            _storage.deinitialize(in: 0..<currentCount)
        }
        _storage.header = 0

        if !keepingCapacity {
            _storage = Heap<Element>.Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the minimum element.
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
    }

    /// Provides borrowing access to the maximum element.
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
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let ptr = unsafe _cachedPtr
        (0..<_storage.count).forEach { index in
            body(unsafe ptr[index])
        }
    }
}
