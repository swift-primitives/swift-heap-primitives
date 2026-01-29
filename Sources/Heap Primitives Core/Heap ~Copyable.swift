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
public import Property_Primitives
public import Pointer_Primitives

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
    public var count: Heap.Index.Count { _storage.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func ensureCapacity(_ minimumCapacity: Index.Count) {
        guard _storage.capacity < minimumCapacity.rawValue else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity.rawValue, _storage.capacity * 2, 4)
        let newStorage = Heap.Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.count

        _storage.move(to: newStorage, count: currentCount)
        newStorage.header = currentCount.rawValue
        _storage.header = 0  // Prevent double-free

        _storage = newStorage
        (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space to store the specified number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(Index.Count(__unchecked: minimumCapacity))
    }
}

// MARK: - Core Operations (Internal)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Appends element without maintaining heap property (for bulk init).
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        let newCount = Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = Heap.Index(__unchecked: (), position: _storage.header)
        _storage.initialize(to: element, at: index)
        _storage.header += 1
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let newCount = Index.Count(__unchecked: _storage.header + 1)
        ensureCapacity(newCount)
        let index = Heap.Index(__unchecked: (), position: _storage.header)
        _storage.initialize(to: element, at: index)
        _storage.header += 1
        bubbleUp(index)
    }

    /// Removes and returns the priority element (min for ascending, max for descending).
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage.move(at: .zero)
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = Heap.Index(__unchecked: (), position: _storage.header - 1)
        swapElements(at: .zero, lastIndex)
        _storage.header -= 1
        let removed = _storage.move(at: lastIndex)
        trickleDown(.zero)
        return removed
    }

    /// Swaps elements at two indices using the cached pointer.
    @usableFromInline
    package mutating func swapElements(at i: Heap.Index, _ j: Heap.Index) {
        _cachedPtr.swap(i, j)
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
        let ptr = _cachedPtr
        let nav = navigate

        switch order {
        case .ascending:
            // Min-heap: bubble up while element < parent
            while let parent = nav.parent(of: current) {
                // If current < parent, swap
                if ptr[current] < ptr[parent] {
                    swapElements(at: current, parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            // Max-heap: bubble up while element > parent
            while let parent = nav.parent(of: current) {
                // If current > parent (parent < current), swap
                if ptr[parent] < ptr[current] {
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

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    ///
    /// For ascending order (min-heap): element trickles down to larger of children.
    /// For descending order (max-heap): element trickles down to smaller of children.
    @usableFromInline
    package mutating func trickleDown(_ startIndex: Heap.Index) {
        var current = startIndex
        let ptr = _cachedPtr
        let nav = navigate

        switch order {
        case .ascending:
            // Min-heap: trickle down, swapping with smaller child
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                // Find smallest among current and children
                if ptr[leftChild] < ptr[smallest] {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if ptr[rightChild] < ptr[smallest] {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                swapElements(at: current, smallest)
                current = smallest
            }

        case .descending:
            // Max-heap: trickle down, swapping with larger child
            while let leftChild = nav.child(.left, of: current) {
                var largest = current

                // Find largest among current and children
                // Using < operator: if largest < leftChild, then leftChild is larger
                if ptr[largest] < ptr[leftChild] {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if ptr[largest] < ptr[rightChild] {
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

// MARK: - Heapify (Floyd's Algorithm)

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let countValue = _storage.header
        guard countValue > 1 else { return }

        // Start from the last non-leaf node and trickle down
        // Last non-leaf is at position (count / 2 - 1)
        var position = countValue / 2 - 1
        while position >= 0 {
            let index = Heap.Index(__unchecked: (), position: position)
            trickleDown(index)
            position -= 1
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
        let currentCount = unsafe base.pointee._storage.count
        if currentCount > .zero {
            unsafe base.pointee._storage.deinitialize(in: 0..<currentCount)
        }
        unsafe base.pointee._storage.header = 0

        if !keepingCapacity {
            unsafe base.pointee._storage = Heap.Storage.create()
            unsafe (base.pointee._cachedPtr = base.pointee._storage._elementsPointer)
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
        return body( _cachedPtr[0])
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
    public func forEach(_ body: (borrowing Element) -> Void) {
        let ptr = _cachedPtr
        (0..<_storage.count).forEach { index in
            body( ptr[index])
        }
    }
}

