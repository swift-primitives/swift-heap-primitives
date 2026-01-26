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

// MARK: - Extremum Namespaces

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for minimum element operations.
    public enum Min {}

    /// Namespace for maximum element operations.
    public enum Max {}
}

// MARK: - Peek Accessor (Non-Mutating)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for non-mutating peek operations.
    ///
    /// A simple struct that provides read-only access to min/max elements
    /// without requiring a mutating context.
    public struct PeekAccessor {
        @usableFromInline
        internal let _storage: Heap<Element>.Storage

        @inlinable
        internal init(storage: Heap<Element>.Storage) {
            self._storage = storage
        }

        /// The minimum element, or `nil` if the heap is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var min: Element? {
            guard _storage.header > 0 else { return nil }
            return _storage.read(at: .zero)
        }

        /// The maximum element, or `nil` if the heap is empty.
        ///
        /// - Complexity: O(1)
        @inlinable
        public var max: Element? {
            guard _storage.header > 0 else { return nil }
            let count = _storage.count
            if count == 1 {
                return _storage.read(at: .zero)
            }
            if count == 2 {
                let index = Heap<Element>.Index(__unchecked: (), position: 1)
                return _storage.read(at: index)
            }

            let idx1 = Heap<Element>.Index(__unchecked: (), position: 1)
            let idx2 = Heap<Element>.Index(__unchecked: (), position: 2)
            let e1 = _storage.read(at: idx1)
            let e2 = _storage.read(at: idx2)
            return e1 < e2 ? e2 : e1
        }
    }

    /// Non-mutating accessor for peeking at min/max elements.
    ///
    /// Use this for read-only access:
    ///
    /// ```swift
    /// let heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.peek.min  // 1
    /// let largest = heap.peek.max   // 8
    /// ```
    @inlinable
    public var peek: PeekAccessor {
        PeekAccessor(storage: _storage)
    }
}

// MARK: - Min Accessor (Mutating)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for minimum element operations.
    ///
    /// A simple struct that provides access to min operations without
    /// compound method names.
    public struct MinAccessor {
        @usableFromInline
        internal var _base: UnsafeMutablePointer<Heap<Element>.MinMax>

        @inlinable
        internal init(_ base: UnsafeMutablePointer<Heap<Element>.MinMax>) {
            unsafe _base = base
        }

        /// Returns the minimum element without removing it.
        ///
        /// - Returns: The minimum element, or `nil` if the heap is empty.
        /// - Complexity: O(1)
        @inlinable
        public var peek: Element? {
            guard !(unsafe _base.pointee.isEmpty) else { return nil }
            return unsafe _base.pointee._storage.read(at: .zero)
        }

        /// Removes and returns the minimum element.
        ///
        /// - Returns: The minimum element.
        /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
        /// - Complexity: O(log n)
        @inlinable
        public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
            unsafe _base.pointee.makeUnique()
            guard let element = unsafe _base.pointee.removeMin() else {
                throw .empty
            }
            return element
        }

        /// Removes and returns the minimum element, or nil if empty.
        ///
        /// - Returns: The minimum element, or `nil` if the heap is empty.
        /// - Complexity: O(log n)
        @inlinable
        public var take: Element? {
            unsafe _base.pointee.makeUnique()
            return unsafe _base.pointee.removeMin()
        }
    }

    /// Accessor for minimum element operations.
    ///
    /// Use this to peek, pop, or take the minimum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.min.peek      // 1 (without removing)
    /// let removed = try heap.min.pop()  // 1 (removes and returns)
    /// let taken = heap.min.take         // next min or nil
    /// ```
    public var min: MinAccessor {
        mutating get {
            unsafe MinAccessor(&self)
        }
    }
}

// MARK: - Max Accessor

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for maximum element operations.
    ///
    /// A simple struct that provides access to max operations without
    /// compound method names.
    public struct MaxAccessor {
        @usableFromInline
        internal var _base: UnsafeMutablePointer<Heap<Element>.MinMax>

        @inlinable
        internal init(_ base: UnsafeMutablePointer<Heap<Element>.MinMax>) {
            unsafe _base = base
        }

        /// Returns the maximum element without removing it.
        ///
        /// - Returns: The maximum element, or `nil` if the heap is empty.
        /// - Complexity: O(1)
        @inlinable
        public var peek: Element? {
            guard !(unsafe _base.pointee.isEmpty) else { return nil }
            let count = unsafe _base.pointee.count
            if count == 1 {
                return unsafe _base.pointee._storage.read(at: .zero)
            }
            if count == 2 {
                let index = Heap<Element>.Index(__unchecked: (), position: 1)
                return unsafe _base.pointee._storage.read(at: index)
            }

            let idx1 = Heap<Element>.Index(__unchecked: (), position: 1)
            let idx2 = Heap<Element>.Index(__unchecked: (), position: 2)
            let e1 = unsafe _base.pointee._storage.read(at: idx1)
            let e2 = unsafe _base.pointee._storage.read(at: idx2)
            return e1 < e2 ? e2 : e1
        }

        /// Removes and returns the maximum element.
        ///
        /// - Returns: The maximum element.
        /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
        /// - Complexity: O(log n)
        @inlinable
        public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
            unsafe _base.pointee.makeUnique()
            guard let element = unsafe _base.pointee.removeMax() else {
                throw .empty
            }
            return element
        }

        /// Removes and returns the maximum element, or nil if empty.
        ///
        /// - Returns: The maximum element, or `nil` if the heap is empty.
        /// - Complexity: O(log n)
        @inlinable
        public var take: Element? {
            unsafe _base.pointee.makeUnique()
            return unsafe _base.pointee.removeMax()
        }
    }

    /// Accessor for maximum element operations.
    ///
    /// Use this to peek, pop, or take the maximum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let largest = heap.max.peek       // 8 (without removing)
    /// let removed = try heap.max.pop()  // 8 (removes and returns)
    /// let taken = heap.max.take         // next max or nil
    /// ```
    public var max: MaxAccessor {
        mutating get {
            unsafe MaxAccessor(&self)
        }
    }
}
