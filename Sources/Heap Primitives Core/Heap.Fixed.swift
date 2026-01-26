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

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for remove operations.
    public enum Remove {}
}

// MARK: - Property Typealias

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns.
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap.Fixed>
}

// MARK: - Properties

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _storage.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _storage.header == capacity }
}


// MARK: - Internal Heap Operations

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element and restores heap property.
    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let index = Heap.Index(__unchecked: (), position: _storage.header)
        _storage.initialize(to: element, at: index)
        _storage.header += 1
        bubbleUp(index)
    }

    /// Removes and returns the priority element.
    @usableFromInline
    package mutating func removePriority() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage.move(at: .zero)
        }

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
        let ptr = unsafe _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// MARK: - Bubble Up (Single-Ended Heap)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element up.
    @usableFromInline
    package mutating func bubbleUp(_ index: Heap.Index) {
        var current = index
        let ptr = unsafe _cachedPtr
        let nav = navigate

        switch order {
        case .ascending:
            while let parent = nav.parent(of: current) {
                if unsafe ptr[current] < ptr[parent] {
                    swapElements(at: current, parent)
                    current = parent
                } else {
                    break
                }
            }
        case .descending:
            while let parent = nav.parent(of: current) {
                if unsafe ptr[parent] < ptr[current] {
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

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Restores heap property by moving element down.
    @usableFromInline
    package mutating func trickleDown(_ startIndex: Heap.Index) {
        var current = startIndex
        let ptr = unsafe _cachedPtr
        let nav = navigate

        switch order {
        case .ascending:
            while let leftChild = nav.child(.left, of: current) {
                var smallest = current

                if unsafe ptr[leftChild] < ptr[smallest] {
                    smallest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if unsafe ptr[rightChild] < ptr[smallest] {
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

                if unsafe ptr[largest] < ptr[leftChild] {
                    largest = leftChild
                }
                if let rightChild = nav.child(.right, of: current) {
                    if unsafe ptr[largest] < ptr[rightChild] {
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

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid heap in O(n).
    @usableFromInline
    package mutating func heapify() {
        let countValue = _storage.header
        guard countValue > 1 else { return }

        var position = countValue / 2 - 1
        while position >= 0 {
            let index = Heap.Index(__unchecked: (), position: position)
            trickleDown(index)
            position -= 1
        }
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
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
    public mutating func push(_ element: consuming Element) -> Heap.Push.Outcome {
        guard _storage.header < capacity else {
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
    /// - Throws: ``Fixed/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func pop() throws(__Heap.Fixed.Error) -> Element {
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    @available(*, deprecated, renamed: "remove.all()")
    public mutating func clear() {
        let count = _storage.count
        if count > .zero {
            _storage.deinitialize(in: 0..<count)
        }
        _storage.header = 0
    }
}

// MARK: - Remove Accessor

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.Fixed = ...
    /// heap.remove.all()  // Remove all elements (capacity unchanged)
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
where Tag == Heap<Element>.Fixed.Remove,
      Base == Heap<Element>.Fixed,
      Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged (fixed-capacity heap).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        let count = unsafe base.pointee._storage.count
        if count > .zero {
            unsafe base.pointee._storage.deinitialize(in: 0..<count)
        }
        unsafe base.pointee._storage.header = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the priority element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the priority element.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withPriority<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
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
        let ptr = unsafe _cachedPtr
        (0..<_storage.count).forEach { index in
            body(unsafe ptr[index])
        }
    }
}


// MARK: - Copy-on-Write (Copyable elements only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap.Storage.create(minimumCapacity: capacity)
            let currentCount = _storage.count
            _storage.copy(to: newStorage, count: currentCount)
            newStorage.header = currentCount.rawValue
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }

    /// Pushes an element onto the heap (CoW-aware).
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: Element) -> Heap.Push.Outcome {
        makeUnique()
        guard _storage.header < capacity else {
            return .overflow(element)
        }
        insert(element)
        return .inserted
    }

    /// Takes and returns the priority element, or nil if empty (CoW-aware).
    @inlinable
    public var take: Element? {
        mutating get {
            makeUnique()
            return removePriority()
        }
    }

    /// Pops and returns the priority element (CoW-aware).
    @inlinable
    public mutating func pop() throws(__Heap.Fixed.Error) -> Element {
        makeUnique()
        guard let element = removePriority() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap (CoW-aware).
    @inlinable
    @available(*, deprecated, renamed: "remove.all()")
    public mutating func clear() {
        makeUnique()
        let count = _storage.count
        if count > .zero {
            _storage.deinitialize(in: 0..<count)
        }
        _storage.header = 0
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == Heap<Element>.Fixed.Remove,
      Base == Heap<Element>.Fixed,
      Element: Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap (CoW-aware).
    ///
    /// The capacity remains unchanged (fixed-capacity heap).
    ///
    /// - Complexity: O(n)
    @inlinable
    public func all() {
        unsafe base.pointee.makeUnique()
        let count = unsafe base.pointee._storage.count
        if count > .zero {
            unsafe base.pointee._storage.deinitialize(in: 0..<count)
        }
        unsafe base.pointee._storage.header = 0
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Returns the priority element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the priority element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !isEmpty else { return nil }
        return _storage.read(at: .zero)
    }

    /// Returns the element at the given typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Heap.Index) -> Element? {
        guard navigate.isValid(index) else { return nil }
        return _storage.read(at: index)
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Creates a fixed heap from a sequence.
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - capacity: Maximum number of elements. Must be non-negative.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
    /// - Note: If elements exceeds capacity, only the first `capacity` elements are kept.
    /// - Complexity: O(n)
    @inlinable
    public init(
        _ elements: some Swift.Sequence<Element>,
        capacity: Int,
        order: Heap.Order = .ascending
    ) throws(Heap.Fixed.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        self._storage = Heap.Storage.create(minimumCapacity: capacity)
        unsafe self._cachedPtr = _storage._elementsPointer
        self.capacity = capacity
        self.order = order

        for element in elements {
            if _storage.header >= capacity { break }
            let index = Heap.Index(__unchecked: (), position: _storage.header)
            _storage.initialize(to: element, at: index)
            _storage.header += 1
        }

        if _storage.header > 1 {
            heapify()
        }
    }
}

// MARK: - Truncate

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        let currentCount = _storage.count
        guard newCount < currentCount.rawValue else { return }
        let targetCount = Swift.max(0, newCount)

        // Use Int..<Count pattern for Range.Lazy creation
        _storage.deinitialize(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// Removes elements beyond the specified count (CoW-aware).
    @inlinable
    public mutating func truncate(to newCount: Int) {
        makeUnique()
        let currentCount = _storage.count
        guard newCount < currentCount.rawValue else { return }
        let targetCount = Swift.max(0, newCount)

        // Use Int..<Count pattern for Range.Lazy creation
        _storage.deinitialize(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

// MARK: - Span Access

extension Heap.Fixed where Element: ~Copyable & Comparison.`Protocol` {
    /// A read-only view of the heap's elements in heap order.
    ///
    /// Elements are in heap order, which is **not** sorted order.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            unsafe Span(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }

    /// A mutable view of the heap's elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    ///   After modification, you may need to re-heapify.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

extension Heap.Fixed where Element: Copyable & Comparison.`Protocol` {
    /// A mutable view of the heap's elements (CoW-aware).
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}
