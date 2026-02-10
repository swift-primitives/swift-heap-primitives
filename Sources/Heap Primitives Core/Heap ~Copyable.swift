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

public import Buffer_Linear_Primitives
public import Property_Primitives

// MARK: - Namespaces

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {}
}

// MARK: - Property Typealias

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>>
}

// MARK: - Properties

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _buffer.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }
}

// MARK: - Core Operations (Internal)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Appends element without maintaining heap property (for bulk init).
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        _buffer.append(element)
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let insertionIndex = _buffer.count.map(Ordinal.init)
        _buffer.append(element)
        bubbleUp(insertionIndex)
    }

    /// Removes and returns the priority element (min for ascending, max for descending).
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == .one {
            return _buffer.removeLast()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)
        _buffer.swap(at: .zero, with: lastIndex)
        let removed = _buffer.removeLast()
        trickleDown(.zero)
        return removed
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    ///
    /// For ascending order (min-heap): element bubbles up while smaller than parent.
    /// For descending order (max-heap): element bubbles up while larger than parent.
    @usableFromInline
    package mutating func bubbleUp(_ index: Heap.Index) {
        var current = index
        let nav = navigate

        switch order {
        case .ascending:
            while let parent = nav.parent(of: current) {
                if _buffer[current] < _buffer[parent] {
                    _buffer.swap(at: current, with: parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if _buffer[parent] < _buffer[current] {
                    _buffer.swap(at: current, with: parent)
                    current = parent
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
    package mutating func trickleDown(_ startIndex: Heap.Index) {
        var current = startIndex
        let nav = navigate

        switch order {
        case .ascending:
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                if _buffer[leftChild] < _buffer[smallest] {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if _buffer[rightChild] < _buffer[smallest] {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                _buffer.swap(at: current, with: smallest)
                current = smallest
            }

        case .descending:
            while let leftChild = nav.child(.left, of: current) {
                var largest = current

                if _buffer[largest] < _buffer[leftChild] {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if _buffer[largest] < _buffer[rightChild] {
                        largest = rightChild
                    }
                }

                if largest == current { break }

                _buffer.swap(at: current, with: largest)
                current = largest
            }
        }
    }
}

// MARK: - Heapify (Floyd's Algorithm)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        guard count > .one else { return }
        // Int escape for division: principled — Cardinal has no division ([IMPL-001])
        let startIdx = Int(bitPattern: count) / 2 - 1
        var idx = Heap.Index(__unchecked: (), Ordinal(UInt(startIdx)))
        while true {
            trickleDown(idx)
            guard idx > .zero else { break }
            idx = try! idx.predecessor.exact()
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
        insert(element)
    }
}

// MARK: - Remove Accessor

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.remove.all()                      // Remove all, release capacity
    /// heap.remove.all(keepingCapacity: true) // Remove all, keep capacity
    /// ```
    public var remove: Property<Remove>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Remove>.View.Typed(&self)
        }
        mutating _modify {
            var view = unsafe Property<Remove>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Heap<Element>.Remove,
      Base == Heap<Element>,
      Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    ///   If `true`, the heap retains its current capacity.
    ///   If `false` (default), the capacity is released.
    /// - Complexity: O(n)
    @inlinable
    public func all(keepingCapacity: Bool = false) {
        unsafe base.pointee._buffer.removeAll()
        if !keepingCapacity {
            unsafe (base.pointee._buffer = Buffer<Element>.Linear(minimumCapacity: .zero))
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
    public mutating func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > .zero else { return nil }
        return body(_buffer[.zero])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `take`.
    ///
    /// - Note: For `Copyable` elements, prefer the `.forEach { }` accessor which
    ///   provides additional operations like `.forEach.consuming { }`.
    ///   This method directly supports `~Copyable` elements.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func forEach(_ body: (borrowing Element) -> Void) {
        var idx: Heap.Index = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            body(_buffer[idx])
            idx += .one
        }
    }
}
