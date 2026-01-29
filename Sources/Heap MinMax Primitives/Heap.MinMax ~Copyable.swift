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
public import Pointer_Primitives

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for minimum element operations.
    public enum Min {}

    /// Namespace for maximum element operations.
    public enum Max {}

    /// Namespace for peek operations.
    public enum Peek {}

    /// Namespace for remove operations.
    public enum Remove {}
}

// MARK: - Properties

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _storage.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func ensureCapacity(_ minimumCapacity: Heap.Index.Count) {
        guard _storage.capacity < minimumCapacity.rawValue else { return }

        let newCapacity = Swift.max(minimumCapacity.rawValue, _storage.capacity * 2, 4)
        let newStorage = Heap.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.count

        _storage.move(to: newStorage, count: currentCount)
        newStorage.header = currentCount.rawValue
        _storage.header = 0

        _storage = newStorage
        (_cachedPtr = _storage._elementsPointer)
    }

    /// Reserves enough space to store the specified number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(Heap.Index.Count(__unchecked: minimumCapacity))
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

        /// Typed index for pointer access.
        @inlinable
        package var index: Heap.Index {
            Heap.Index(__unchecked: (), position: offset)
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
        let newCount = Heap.Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = Heap.Index(__unchecked: (), position: _storage.header)
        _storage.initialize(to: element, at: index)
        _storage.header += 1
    }

    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let newCount = Heap.Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = _storage.header
        let typedIndex = Heap.Index(__unchecked: (), position: index)
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

        let lastNode = Node(offset: _storage.header - 1)
        swapElements(at: Node.root.index, lastNode.index)
        _storage.header -= 1
        let removed = _storage.move(at: lastNode.index)
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
            let index = Heap.Index(__unchecked: (), position: 1)
            return _storage.move(at: index)
        }

        let maxNode = _cachedPtr[Node.leftMax.index] < _cachedPtr[Node.rightMax.index]
            ? Node.rightMax
            : Node.leftMax

        let lastOffset = _storage.header - 1
        let lastNode = Node(offset: lastOffset)
        swapElements(at: maxNode.index, lastNode.index)
        _storage.header -= 1
        let removed = _storage.move(at: lastNode.index)

        if maxNode.offset < _storage.header {
            trickleDownMax(maxNode)
        }

        return removed
    }

    /// Swaps elements at two indices using the cached pointer.
    @usableFromInline
    package mutating func swapElements(at i: Heap.Index, _ j: Heap.Index) {
        _cachedPtr.swap(i, j)
    }
}

// MARK: - Bubble Up (MinMax Heap)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func bubbleUp(_ node: Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let nodeIsLess = _cachedPtr[node.index] < _cachedPtr[parent.index]
        let parentIsLess = _cachedPtr[parent.index] < _cachedPtr[node.index]

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            swapElements(at: node.index, parent.index)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = _cachedPtr[grandparent.index] < _cachedPtr[node.index]
                guard !gpIsLess else { break }
                swapElements(at: node.index, grandparent.index)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = _cachedPtr[node.index] < _cachedPtr[grandparent.index]
                guard !nodeIsLessGp else { break }
                swapElements(at: node.index, grandparent.index)
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

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var smallest = node
            let rightChild = node.rightChild()

            if _cachedPtr[leftChild.index] < _cachedPtr[smallest.index] {
                smallest = leftChild
            }
            if rightChild.offset < count {
                if _cachedPtr[rightChild.index] < _cachedPtr[smallest.index] {
                    smallest = rightChild
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                let gc = Node(offset: gcOffset, level: gc0.level)
                if _cachedPtr[gc.index] < _cachedPtr[smallest.index] {
                    smallest = gc
                }
            }

            if smallest.offset == node.offset { break }

            swapElements(at: node.index, smallest.index)

            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if _cachedPtr[parent.index] < _cachedPtr[smallest.index] {
                    swapElements(at: smallest.index, parent.index)
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

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var largest = node
            let rightChild = node.rightChild()

            if _cachedPtr[largest.index] < _cachedPtr[leftChild.index] {
                largest = leftChild
            }
            if rightChild.offset < count {
                if _cachedPtr[largest.index] < _cachedPtr[rightChild.index] {
                    largest = rightChild
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                let gc = Node(offset: gcOffset, level: gc0.level)
                if _cachedPtr[largest.index] < _cachedPtr[gc.index] {
                    largest = gc
                }
            }

            if largest.offset == node.offset { break }

            swapElements(at: node.index, largest.index)

            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                if _cachedPtr[largest.index] < _cachedPtr[parent.index] {
                    swapElements(at: largest.index, parent.index)
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
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the minimum element.
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(_cachedPtr[Node.root.index])
    }

    /// Provides borrowing access to the maximum element.
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return body(_cachedPtr[Node.root.index]) }
        if count == 2 { return body(_cachedPtr[Node.leftMax.index]) }

        let maxNode = _cachedPtr[Node.leftMax.index] < _cachedPtr[Node.rightMax.index]
            ? Node.rightMax
            : Node.leftMax
        return body(_cachedPtr[maxNode.index])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// - Note: For `Copyable` elements, prefer the `.forEach { }` accessor which
    ///   provides additional operations like `.forEach.consuming { }`.
    ///   This method directly supports `~Copyable` elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        (0..<count).forEach { index in
            body(_cachedPtr[index])
        }
    }
}
