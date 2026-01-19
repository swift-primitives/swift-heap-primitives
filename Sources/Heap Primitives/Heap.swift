// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Double-ended priority queue backed by a min-max heap.
///
/// `Heap` provides O(1) access to both the minimum and maximum elements,
/// with O(log n) insertion and removal. Based on min-max heaps
/// (Atkinson et al. 1986).
///
/// ## API
///
/// Operations use nested accessors:
///
/// ```swift
/// var heap: Heap<Int> = [3, 1, 4, 1, 5]
///
/// // Peek (O(1))
/// if let min = heap.peek.min { ... }
/// if let max = heap.peek.max { ... }
///
/// // Pop (throws if empty)
/// let min = try heap.pop.min()
/// let max = try heap.pop.max()
///
/// // Take (returns nil if empty)
/// while let min = heap.take.min { process(min) }
///
/// // Replace
/// let oldMin = try heap.replace.min(with: 0)
///
/// // Push
/// heap.push(42)
/// heap.push.contentsOf([1, 2, 3])
/// ```
///
/// ## Thread Safety
///
/// Not thread-safe for concurrent mutation. Synchronize externally.
///
/// ## Complexity
///
/// - Peek min/max: O(1)
/// - Push: O(log n)
/// - Pop min/max: O(log n)
/// - Init from sequence: O(n)
public struct Heap<Element: Comparable> {
    @usableFromInline
    var storage: Storage

    /// Creates an empty heap.
    @inlinable
    public init() {
        self.storage = Storage()
    }
}

// MARK: - Properties

extension Heap {
    /// The number of elements in the heap.
    @inlinable
    public var count: Int {
        storage.count
    }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// A read-only view into the underlying storage.
    ///
    /// The elements are in heap order, which is **not** sorted order.
    /// Do not rely on any particular ordering - it may change between
    /// versions.
    ///
    /// - Complexity: O(n) to copy elements.
    @inlinable
    public var unordered: [Element] {
        Array(storage.elements)
    }
}

// MARK: - Initialization from Sequence

extension Heap {
    /// Creates a heap from a sequence using O(n) heapification.
    ///
    /// - Parameter elements: The sequence of elements.
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        self.storage = Storage(elements)
    }
}

// MARK: - Reserve Capacity

extension Heap {
    /// Reserves enough space to store the specified number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        storage.reserveCapacity(minimumCapacity)
    }
}

// MARK: - Remove All

extension Heap {
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepingCapacity)
    }
}

// MARK: - Sendable

extension Heap: Sendable where Element: Sendable {}

// MARK: - Equatable

extension Heap: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage.elements == rhs.storage.elements
    }
}

// MARK: - Hashable

extension Heap: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage.elements)
    }
}

// MARK: - ExpressibleByArrayLiteral

extension Heap: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - CustomStringConvertible

extension Heap: CustomStringConvertible {
    public var description: String {
        "Heap(\(count) elements)"
    }
}
