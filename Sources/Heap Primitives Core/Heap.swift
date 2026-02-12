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

import Buffer_Linear_Primitives

// MARK: - Heap (Canonical Single-Ended Binary Heap)

/// Canonical binary heap with configurable ordering.
///
/// `Heap` is the canonical heap primitive, providing O(log n) insertion
/// and O(log n) removal of the priority element. The ordering determines
/// whether the minimum or maximum element has highest priority.
///
/// ## Usage
///
/// ```swift
/// var minHeap = Heap<Int>(order: .ascending)   // min-heap
/// var maxHeap = Heap<Int>(order: .descending)  // max-heap
///
/// minHeap.push(42)
/// let top = minHeap.peek       // O(1) - the priority element
/// let removed = try minHeap.pop()  // O(log n)
/// ```
///
/// ## Move-Only Support
///
/// `Heap` supports both `~Copyable` (move-only) and `Copyable` elements:
///
/// ```swift
/// struct FileHandle: ~Copyable, Comparison.`Protocol` { ... }
/// var handles = Heap<FileHandle>(order: .ascending)  // ~Copyable heap
/// ```
///
/// ## Variants
///
/// - ``Heap``: Dynamic, growable (this type)
/// - ``Heap/Binary``: Typealias to `Heap` for API symmetry
/// - ``Heap/Fixed``: Fixed capacity, heap-allocated
/// - ``Heap/Static``: Compile-time capacity, inline storage
/// - ``Heap/Small``: Small-buffer optimization
/// - ``Heap/MinMax``: Double-ended min-max heap
///
/// ## Thread Safety
///
/// Not thread-safe for concurrent mutation. Synchronize externally.
///
/// ## Complexity
///
/// - Peek: O(1)
/// - Push: O(log n)
/// - Pop: O(log n)
/// - Init from sequence: O(n)
@safe
public struct Heap<Element: ~Copyable & Comparison.`Protocol`>: ~Copyable {

    // MARK: - Order Enum

    /// Ordering direction for heap operations.
    public enum Order: Sendable, Hashable {
        /// Ascending order (min-heap): smallest element has highest priority.
        case ascending
        /// Descending order (max-heap): largest element has highest priority.
        case descending
    }

    // MARK: - Error Enum

    /// Errors that can occur during heap operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty heap.
        case empty
    }

    // MARK: - Stored Properties

    /// The ordering direction for this heap.
    public let order: Order

    @usableFromInline
    package var _buffer: Buffer<Element>.Linear

    // MARK: - Init

    /// Creates an empty heap with the specified ordering.
    ///
    /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
    @inlinable
    public init(order: Order = .ascending) {
        self.order = order
        self._buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
    }

    // MARK: - Fixed Capacity Heap
    @safe
    public struct Fixed: ~Copyable {
        /// Errors that can occur during fixed heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// An operation was attempted on an empty heap.
            case empty
        }

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Bounded

        /// The ordering direction for this heap.
        public let order: Order

        /// Creates an empty fixed-capacity heap.
        ///
        /// - Parameters:
        ///   - capacity: Maximum number of elements.
        ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
        /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(
            capacity: Int,
            order: Order = .ascending
        ) throws(Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            // Boundary: Int → typed count. Cardinal(UInt(...)) is the canonical Int→Cardinal path.
            self._buffer = Buffer<Element>.Linear.Bounded(
                minimumCapacity: Heap.Index.Count(__unchecked: (), Cardinal(UInt(capacity)))
            )
            self.order = order
        }
    }

    // MARK: - Push Outcome

    /// Outcome of a push operation on a fixed heap.
    public enum Push: ~Copyable {
        /// Outcome of pushing an element.
        public enum Outcome: ~Copyable {
            /// The element was successfully inserted.
            case inserted
            /// The heap was full; the element is returned to the caller.
            case overflow(Element)
        }
    }

    // MARK: - Static (nested in body for value generic parameter per COPY-FIX-002)

    /// A fixed-capacity, inline-storage binary heap with compile-time capacity.
    ///
    /// `Heap.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Errors that can occur during static heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        /// The ordering direction for this heap.
        public let order: Order

        /// Creates an empty inline heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
            self.order = order
        }
    }

    // MARK: - Small (nested in body for value generic parameter per COPY-FIX-002)

    /// A binary heap with small-buffer optimization (SmallVec pattern).
    ///
    /// `Heap.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Errors that can occur during small heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// The ordering direction for this heap.
        public let order: Order

        /// Creates an empty small heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
            self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
            self.order = order
        }
    }

    // MARK: - MinMax Heap (Declaration Only)

    /// Double-ended priority queue backed by a binary min-max heap.
    ///
    /// Declared here (inside `Heap`) due to Swift's `~Copyable` constraint propagation rules.
    /// All operations are implemented in the `Heap MinMax Primitives` module.
    ///
    /// See ``Heap/MinMax`` documentation in `Heap MinMax Primitives` for full API details.
    @safe
    public struct MinMax: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Element>.Linear

        /// Creates an empty min-max heap.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
        }
    }

    // MARK: - Ordering Typealias

    /// Comparison protocol for heap elements.
    ///
    /// This is a typealias to `Comparison.Protocol` from comparison-primitives,
    /// which provides borrowing-based comparison for `~Copyable` types.
    public typealias Ordering = Comparison_Primitives.Comparison.`Protocol`

    // MARK: - Variant Typealiases

    /// Typealias for ``Heap`` itself.
    ///
    /// `Heap.Binary` is an alias for `Heap` itself, provided for API symmetry
    /// with `Heap.MinMax`. Both are valid ways to create a canonical single-ended heap.
    public typealias Binary = Heap
}

// MARK: - Conditional Copyable

/// `Heap` is `Copyable` when its elements are `Copyable`.
extension Heap: Copyable where Element: Copyable {}

/// `Heap.Fixed` is `Copyable` when its elements are `Copyable`.
extension Heap.Fixed: Copyable where Element: Copyable {}

/// `Heap.MinMax` is `Copyable` when its elements are `Copyable`.
extension Heap.MinMax: Copyable where Element: Copyable {}

// Note: Heap.Static is UNCONDITIONALLY ~Copyable due to deinit requirement.
// Note: Heap.Small is UNCONDITIONALLY ~Copyable due to deinit requirement.

// MARK: - Sendable

extension Heap: @unchecked Sendable where Element: Sendable {}
extension Heap.Fixed: @unchecked Sendable where Element: Sendable {}
extension Heap.MinMax: @unchecked Sendable where Element: Sendable {}
extension Heap.Static: @unchecked Sendable where Element: Sendable {}
extension Heap.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Push.Outcome Conditional Conformances

extension Heap.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Push.Outcome: Sendable where Element: Sendable {}
