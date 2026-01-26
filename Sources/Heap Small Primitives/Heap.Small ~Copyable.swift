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
            unsafe heapStorage.deinitialize(in: 0..<base.pointee.count)
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


// MARK: - Internal Scoped Pointer Access

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Scoped mutable access to element at index.
    @usableFromInline
    @unsafe
    package mutating func withPointer<R: ~Copyable>(
        at index: Heap.Index,
        _ body: (Pointer<Element>.Mutable) -> R
    ) -> R {
        if let ptr = heapPtr {
            let elementPtr = ptr.advanced(by: Heap.Index.Offset(index.position.rawValue))
            return body(elementPtr)
        } else {
            return unsafe inline.withPointer(at: index, body)
        }
    }

    /// Scoped read-only access to element at index.
    @usableFromInline
    @unsafe
    package mutating func withReadPointer<R: ~Copyable>(
        at index: Heap.Index,
        _ body: (Pointer<Element>) -> R
    ) -> R {
        if let ptr = heapPtr {
            let elementPtr = ptr.advanced(by: Heap.Index.Offset(index.position.rawValue)).immutable
            return body(elementPtr)
        } else {
            return unsafe inline.withReadPointer(at: index, body)
        }
    }

    /// Compares elements at two indices using less-than.
    @usableFromInline
    package mutating func isLess(at i: Heap.Index, than j: Heap.Index) -> Bool {
        if let ptr = heapPtr {
            return ptr[i] < ptr[j]
        } else {
            return inline.isLess(at: i, than: j)
        }
    }
}

// MARK: - Internal Heap Operations

extension Heap.Small where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let index = Heap.Index(__unchecked: (), position: count.rawValue)
        if let ptr = heapPtr {
            ptr.advanced(by: Heap.Index.Offset(index.position.rawValue)).initialize(to: element)
        } else {
            inline.initialize(to: element, at: index)
        }
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
            if let ptr = heapPtr {
                return ptr.move()
            } else {
                return inline.move(at: .zero)
            }
        }

        let lastIndex = Heap.Index(__unchecked: (), position: count.rawValue - 1)
        swapElements(at: .zero, lastIndex)
        count = Heap.Index.Count(__unchecked: count.rawValue - 1)
        if heap != nil {
            heap!.header = count.rawValue
        }
        let removed: Element
        if let ptr = heapPtr {
            removed = ptr.advanced(by: Heap.Index.Offset(lastIndex.position.rawValue)).move()
        } else {
            removed = inline.move(at: lastIndex)
        }
        trickleDown(.zero)
        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package mutating func swapElements(at i: Heap.Index, _ j: Heap.Index) {
        if let ptr = heapPtr {
            // Heap: stable allocation, direct swap OK
            let ptrI = ptr.advanced(by: Heap.Index.Offset(i.position.rawValue))
            let ptrJ = ptr.advanced(by: Heap.Index.Offset(j.position.rawValue))
            let temp = ptrI.move()
            ptrI.initialize(to: ptrJ.move())
            ptrJ.initialize(to: temp)
        } else {
            // Inline: use scoped access
            inline.swap(at: i, j)
        }
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
                if isLess(at: current, than: parent) {
                    swapElements(at: current, parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if isLess(at: parent, than: current) {
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

                if isLess(at: leftChild, than: smallest) {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if isLess(at: rightChild, than: smallest) {
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

                if isLess(at: largest, than: leftChild) {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if isLess(at: largest, than: rightChild) {
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
        guard let heapStorage = heap, let _ = heapPtr else {
            preconditionFailure("pushToHeap called without heap storage")
        }

        if count.rawValue >= heapStorage.capacity {
            growHeap(minimumCapacity: count.rawValue + 1)
        }

        let index = Heap.Index(__unchecked: (), position: count.rawValue)
        heapPtr!.advanced(by: Heap.Index.Offset(count.rawValue)).initialize(to: element)
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
        heapPtr = newStorage._elementsPointer
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
    public mutating func pop() throws(Heap.Small<inlineCapacity>.Error) -> Element {
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
    public mutating func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > .zero else { return nil }
        return unsafe withReadPointer(at: .zero) { ptr in
            body(ptr.pointee)
        }
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
        (0..<count).forEach { index in
            unsafe withReadPointer(at: index) { ptr in
                body(ptr.pointee)
            }
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
        mutating get {
            guard !isEmpty else { return nil }
            return unsafe withReadPointer(at: .zero) { $0.pointee }
        }
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
    ///
    /// Note: For inline storage, the pointer is valid for the duration of the
    /// `_read` accessor because the struct is borrowed and cannot move.
    @inlinable
    public var span: Span<Element> {
        mutating _read {
            if let ptr = heapPtr {
                yield unsafe Span(_unsafeStart: ptr.base, count: count.rawValue)
            } else {
                // Within _read, self is borrowed, so the pointer from
                // _unsafePointer remains valid for the yield duration
                let ptr = unsafe inline._unsafePointer(at: .zero)
                yield unsafe Span(_unsafeStart: ptr.base, count: count.rawValue)
            }
        }
    }

    /// Mutable span of the heap elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        mutating _read {
            if let ptr = heapPtr {
                yield unsafe MutableSpan(_unsafeStart: ptr.base, count: count.rawValue)
            } else {
                let ptr = unsafe inline._unsafePointer(at: .zero)
                yield unsafe MutableSpan(_unsafeStart: ptr.base, count: count.rawValue)
            }
        }
        mutating _modify {
            if let ptr = heapPtr {
                var s = unsafe MutableSpan(_unsafeStart: ptr.base, count: count.rawValue)
                yield &s
            } else {
                let ptr = unsafe inline._unsafePointer(at: .zero)
                var s = unsafe MutableSpan(_unsafeStart: ptr.base, count: count.rawValue)
                yield &s
            }
        }
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

extension Heap.Small where Element: ~Copyable {
    
    /// Whether the heap is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { heap != nil }

    /// Spills inline storage to heap.
    @usableFromInline
    package mutating func spillToHeap(minimumCapacity: Int) {
        precondition(heap == nil, "Already spilled")

        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = Heap.Storage.create(minimumCapacity: newCapacity)
        newStorage.header = count.rawValue

        inline.move(to: newStorage, count: count)

        heap = newStorage
        heapPtr = newStorage._elementsPointer
    }
}
