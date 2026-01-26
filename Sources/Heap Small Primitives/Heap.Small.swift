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

// MARK: - Namespaces

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {}
}

// MARK: - Property Typealias

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap<Element>.Small<inlineCapacity>>
}

// MARK: - Remove Accessor

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.Small<8> = ...
    /// heap.remove.all()  // Remove all elements
    /// ```
    public var remove: Property<Remove>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Remove>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Remove>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed.Valued
where Tag == Heap<Element>.Small<n>.Remove,
      Base == Heap<Element>.Small<n>,
      Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// Does not shrink back to inline storage if spilled.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        guard unsafe base.pointee.count > .zero else { return }

        if let heapStorage = unsafe base.pointee.heap {
            heapStorage.deinitialize(in: 0..<base.pointee.count)
            heapStorage.header = 0
        } else {
            unsafe base.pointee.inline.deinitialize(count: base.pointee.count)
        }
        unsafe base.pointee.count = .zero
    }
}

// MARK: - Properties

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }

    /// The current capacity (inline or heap).
    @inlinable
    public var capacity: Int {
        if let heapStorage = heap {
            return heapStorage.capacity
        }
        return inlineCapacity
    }
}


// MARK: - Internal Pointer Access

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Returns a pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package mutating func pointer(at index: Heap.Index) -> UnsafeMutablePointer<Element> {
        if let ptr = unsafe heapPtr {
            return unsafe ptr + index.position.rawValue
        } else {
            return unsafe inline.pointer(at: index)
        }
    }

    /// Returns a read pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package func readPointer(at index: Heap.Index) -> UnsafePointer<Element> {
        if let ptr = unsafe heapPtr {
            return unsafe UnsafePointer(ptr + index.position.rawValue)
        } else {
            return unsafe inline.read(at: index)
        }
    }
}

// MARK: - Internal Heap Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let index = Heap.Index(__unchecked: (), position: count.rawValue)
        unsafe pointer(at: index).initialize(to: element)
        count = Heap.Index.Count(__unchecked: count.rawValue + 1)
        if heap != nil {
            heap!.header = count.rawValue
        }
        bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard count > .zero else { return nil }

        if count.rawValue == 1 {
            count = .zero
            if heap != nil {
                heap!.header = 0
            }
            return unsafe pointer(at: .zero).move()
        }

        let lastIndex = Heap.Index(__unchecked: (), position: count.rawValue - 1)
        swapElements(at: .zero, lastIndex)
        count = Heap.Index.Count(__unchecked: count.rawValue - 1)
        if heap != nil {
            heap!.header = count.rawValue
        }
        let removed = unsafe pointer(at: lastIndex).move()
        trickleDown(.zero)
        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package mutating func swapElements(at i: Heap.Index, _ j: Heap.Index) {
        let ptrI = unsafe pointer(at: i)
        let ptrJ = unsafe pointer(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func bubbleUp(_ index: Heap.Index) {
        var current = index
        let nav = navigate

        switch order {
        case .ascending:
            while let parent = nav.parent(of: current) {
                if unsafe readPointer(at: current).pointee < readPointer(at: parent).pointee {
                    swapElements(at: current, parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if unsafe readPointer(at: parent).pointee < readPointer(at: current).pointee {
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    @usableFromInline
    package mutating func trickleDown(_ startIndex: Heap.Index) {
        var current = startIndex
        let nav = navigate

        switch order {
        case .ascending:
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                if unsafe readPointer(at: leftChild).pointee < readPointer(at: smallest).pointee {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if unsafe readPointer(at: rightChild).pointee < readPointer(at: smallest).pointee {
                        smallest = rightChild
                    }
                }

                if smallest == current { break }

                swapElements(at: current, smallest)
                current = smallest
            }

        case .descending:
            while let leftChild = nav.child(.left, of: current) {
                var largest = current

                if unsafe readPointer(at: largest).pointee < readPointer(at: leftChild).pointee {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if unsafe readPointer(at: largest).pointee < readPointer(at: rightChild).pointee {
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

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let countValue = count.rawValue
        guard countValue > 1 else { return }

        var position = countValue / 2 - 1
        while position >= 0 {
            let index = Heap.Index(__unchecked: (), position: position)
            trickleDown(index)
            position -= 1
        }
    }
}

// MARK: - Heap Growth

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Internal: push element to heap storage.
    @usableFromInline
    package mutating func pushToHeap(_ element: consuming Element) {
        guard let heapStorage = heap, let _ = unsafe heapPtr else {
            preconditionFailure("pushToHeap called without heap storage")
        }

        if count.rawValue >= heapStorage.capacity {
            growHeap(minimumCapacity: count.rawValue + 1)
        }

        let index = Heap.Index(__unchecked: (), position: count.rawValue)
        unsafe (heapPtr! + count.rawValue).initialize(to: element)
        count = Heap.Index.Count(__unchecked: count.rawValue + 1)
        heapStorage.header = count.rawValue
        bubbleUp(index)
    }

    /// Internal: grow heap storage.
    @usableFromInline
    package mutating func growHeap(minimumCapacity: Int) {
        guard let oldStorage = heap else {
            preconditionFailure("growHeap called without heap storage")
        }

        let newCapacity = Swift.max(minimumCapacity, oldStorage.capacity * 2)
        let newStorage = Heap.Storage.create(minimumCapacity: newCapacity)

        oldStorage.move(to: newStorage, count: count)
        newStorage.header = count.rawValue
        oldStorage.header = 0

        heap = newStorage
        unsafe (heapPtr = newStorage._elementsPointer)
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
        if heap != nil {
            pushToHeap(element)
        } else if count.rawValue < inlineCapacity {
            insert(element)
        } else {
            spillToHeap(minimumCapacity: count.rawValue + 1)
            pushToHeap(element)
        }
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
    /// - Throws: ``Small/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Small.Error) -> Element {
        guard let element = removePriority() else {
            throw .empty
        }
        return element
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
        guard count > .zero else { return nil }
        return unsafe body(readPointer(at: .zero).pointee)
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
        (0..<count).forEach { index in
            body(unsafe readPointer(at: index).pointee)
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
        return unsafe readPointer(at: .zero).pointee
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
        guard newCount < count.rawValue else { return }
        let targetCount = Swift.max(0, newCount)
        let targetCountTyped = Heap.Index.Count(__unchecked: targetCount)

        // Use Int..<Count pattern for Range.Lazy creation
        if let heapStorage = heap {
            heapStorage.deinitialize(in: targetCount..<count)
            heapStorage.header = targetCount
        } else {
            inline.deinitialize(in: targetCount..<count)
        }
        count = targetCountTyped
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
            if let ptr = unsafe heapPtr {
                yield unsafe Span(_unsafeStart: ptr, count: count.rawValue)
            } else {
                yield unsafe Span(_unsafeStart: inline.read(at: .zero), count: count.rawValue)
            }
        }
    }

    /// Mutable span of the heap elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        _read {
            if let ptr = unsafe heapPtr {
                yield unsafe MutableSpan(_unsafeStart: ptr, count: count.rawValue)
            } else {
                let ptr = unsafe UnsafeMutablePointer(mutating: inline.read(at: .zero))
                yield unsafe MutableSpan(_unsafeStart: ptr, count: count.rawValue)
            }
        }
        _modify {
            if let ptr = unsafe heapPtr {
                var s = unsafe MutableSpan(_unsafeStart: ptr, count: count.rawValue)
                yield &s
            } else {
                var s = unsafe MutableSpan(_unsafeStart: inlineMutableBasePointer(), count: count.rawValue)
                yield &s
            }
        }
    }

    /// Returns the mutable inline base pointer.
    @usableFromInline
    @unsafe
    package mutating func inlineMutableBasePointer() -> UnsafeMutablePointer<Element> {
        unsafe inline.pointer(at: .zero)
    }
}

// MARK: - Small Navigate Accessor

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Index of the root element, or `nil` if the heap is empty.
    @inlinable
    public var root: Heap.Index? {
        isEmpty ? nil : .zero
    }

    /// Navigation accessor for index operations.
    @inlinable
    public var navigate: Heap.Navigate {
        Heap.Navigate(_count: count)
    }
}
