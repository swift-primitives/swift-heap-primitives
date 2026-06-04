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

public import Buffer_Linear_Primitive
import Storage_Heap_Primitives
public import Buffer_Linear_Primitives
public import Comparison_Primitives
public import Index_Primitives

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
/// ## Iteration
///
/// `Heap` conforms to `Iterable` (multipass, borrowing) and — when `Element` is
/// `Copyable` — `Sequenceable` (single-pass, consuming). Both are vended in the
/// `Heap Primitives` ops module. Elements are yielded in heap order, which is
/// **not** sorted order; for sorted iteration, repeatedly call `take`.
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
// WHY: Category D — structural Sendable workaround; the type is
// WHY: structurally value-safe but the compiler cannot synthesize
// WHY: Sendable due to a stored pointer / generic parameter shape.
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

    /// Element storage using Buffer.Linear from buffer-primitives.
    ///
    /// `@usableFromInline package` ([MOD-036] refined-C): the hot
    /// `~Copyable`/`Copyable` operation surface co-located in this (type)
    /// module inlines cross-package to zero-witness-dispatch; the cold
    /// sequence-family conformances in the ops module reach this storage
    /// only through the public `span` / `makeIterator` witnesses.
    @usableFromInline
    package var _buffer: Buffer<Storage<Element>.Heap>.Linear

    // MARK: - Init

    /// Creates an empty heap with the specified ordering.
    ///
    /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
    @inlinable
    public init(order: Order = .ascending) {
        self.order = order
        self._buffer = Buffer<Storage<Element>.Heap>.Linear(minimumCapacity: .zero)
    }

    // MARK: - Fixed Capacity Heap
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Fixed: ~Copyable {
        /// Errors that can occur during fixed heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// An operation was attempted on an empty heap.
            case empty
            /// The heap is full and cannot accept more elements.
            case overflow
        }

        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Heap>.Linear.Bounded

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
            self._buffer = Buffer<Storage<Element>.Heap>.Linear.Bounded(
                minimumCapacity: Heap.Index.Count(_unchecked: Cardinal(UInt(capacity)))
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

    // MARK: - MinMax Heap (Declaration Only)

    /// Double-ended priority queue backed by a binary min-max heap.
    ///
    /// Declared here (inside `Heap`) due to Swift's `~Copyable` constraint propagation rules.
    /// All operations are implemented in the `Heap MinMax Primitive` / `Heap MinMax Primitives`
    /// modules.
    ///
    /// See ``Heap/MinMax`` documentation for full API details.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct MinMax: ~Copyable {
        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Heap>.Linear

        /// Creates an empty min-max heap.
        @inlinable
        public init() {
            self._buffer = Buffer<Storage<Element>.Heap>.Linear(minimumCapacity: .zero)
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

/// Sendable conformance for `Heap`.
///
/// ## Safety Invariant
///
/// `Heap` is `~Copyable` (move-only), so at most one owner exists at any point.
/// Sending across threads is sound because the compiler enforces that the
/// sender loses access after the move — there is no aliasing to race on.
/// The internal `Buffer<Storage<Element>.Heap>.Linear` is owned exclusively by the heap
/// and moves with it.
///
/// ## Intended Use
///
/// - Transferring a prepared priority queue to a worker thread.
/// - Handing off a heap of `~Copyable` resources across actors.
/// - Actor-owned priority queue constructed outside the actor and passed in at init.
///
/// ## Non-Goals
///
/// - Does not grant concurrent access to a live heap.
/// - `~Copyable` forbids multiple references across threads by construction.
/// - Does not synchronize push/pop; external synchronization is required.
extension Heap: @unsafe @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Heap.Fixed`.
///
/// ## Safety Invariant
///
/// `Heap.Fixed` is `~Copyable`. Single ownership is enforced by the type
/// system; the fixed-capacity `Buffer<Storage<Element>.Heap>.Linear.Bounded` it owns
/// transfers with it across isolation boundaries.
///
/// ## Intended Use
///
/// - Transferring a pre-sized priority queue to a worker or actor.
/// - Embedded/real-time contexts where capacity is bounded and the heap is
///   constructed at startup then moved to its consumer.
///
/// ## Non-Goals
///
/// - Not a shared, concurrent fixed-capacity queue.
/// - Does not guarantee overflow safety under concurrent push.
extension Heap.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Heap.MinMax`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax` is `~Copyable`; its backing `Buffer<Storage<Element>.Heap>.Linear`
/// transfers under unique ownership. Cross-thread sends relinquish the
/// sender's access, preventing data races by construction.
///
/// ## Intended Use
///
/// - Handing off a double-ended priority queue to a scheduler that needs
///   both min and max access.
/// - Transferring a min-max heap of `~Copyable` resources for deadline-ordered
///   processing.
///
/// ## Non-Goals
///
/// - Does not support concurrent min-pop + max-pop from multiple threads.
/// - Not thread-safe for mutation; external synchronization required.
extension Heap.MinMax: @unsafe @unchecked Sendable where Element: Sendable {}

// MARK: - Push.Outcome Conditional Conformances

extension Heap.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Push.Outcome: Sendable where Element: Sendable {}
