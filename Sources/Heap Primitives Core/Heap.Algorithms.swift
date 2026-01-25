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

// MARK: - Bubble Up

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func _bubbleUp(_ node: Heap<Element>.Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let ptr = unsafe _cachedPtr

        // Compare using Comparison.Protocol with borrowing
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
                guard !gpIsLess else { break }  // node < grandparent
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = unsafe ptr[node.offset] < ptr[grandparent.offset]
                guard !nodeIsLessGp else { break }  // node > grandparent
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    package mutating func _trickleDownMin(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            // Find smallest among children and grandchildren
            var smallest = node
            var smallestOffset = node.offset

            // Check children
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

            // Check grandchildren
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

            // If swapped with grandchild, may need to swap with parent
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

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    package mutating func _trickleDownMax(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            // Find largest among children and grandchildren
            var largest = node
            var largestOffset = node.offset

            // Check children
            let rightChild = node.rightChild()

            // largest < leftChild means leftChild > largest
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

            // Check grandchildren
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

            // If swapped with grandchild, may need to swap with parent
            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                // newValue < parentValue
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

// MARK: - Heapify (Floyd's Algorithm)

extension Heap.Binary where Element: ~Copyable & Comparison.`Protocol` {
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
