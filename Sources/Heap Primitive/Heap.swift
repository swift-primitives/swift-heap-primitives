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
public import Buffer_Linear_Bounded_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Comparison_Primitives
public import Column_Primitives
public import Shared_Primitive
import Index_Primitives

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
/// - `Heap.MinMax`: Double-ended min-max heap (parked at the W5 quarantine;
///   restores at heap's full template round)
///
/// ## Iteration
///
/// Element traversal is scoped: `forEach` (ops module) and the scoped span
/// form (`withSpan`) borrow the elements in heap order, which is **not**
/// sorted order; for sorted iteration, repeatedly call `take`. The
/// protocol-lattice memberships (`Iterable` / `Sequenceable`) are withdrawn
/// at the A-1 interim reshape — the stored `Shared` column has no returning
/// span or consuming extraction; they re-materialize when `Shared` gains
/// those surfaces upstream (recorded as future work).
///
/// ## Copy-on-Write
///
/// When `Element` is `Copyable`, `Heap` uses copy-on-write semantics:
/// copies share storage until mutation, providing efficient value semantics.
/// The CoW machinery is the ratified `Shared` column (the W4/W5 tower
/// design): the stored buffer rides a refcounted box whose uniqueness gate
/// (`withUnique`) runs before every mutation. For `~Copyable` elements the
/// heap is move-only and the gate is a no-op.
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

    /// Element storage: the `Shared` column over the growable heap buffer
    /// (`Column.Heap<Element>` = `Buffer.Linear` over system-allocated
    /// contiguous storage).
    ///
    /// Conditional copyability flows from the column (`Shared<E, B>` is
    /// `Copyable` iff `E` is), and value semantics ride the ratified CoW box —
    /// the A-1 interim reshape (public element-generic API preserved; the
    /// hand-rolled `ensureUnique` CoW is deleted).
    ///
    /// `@usableFromInline package` ([MOD-036] refined-C): the hot
    /// `~Copyable`/`Copyable` operation surface co-located in this (type)
    /// module inlines cross-package to zero-witness-dispatch; the cold
    /// sequence-family ops in the ops module reach this storage through the
    /// same package-visible field.
    @usableFromInline
    package var _buffer: Shared<Element, Column.Heap<Element>>

    // MARK: - Init

    /// Creates an empty heap of move-only elements with the specified ordering.
    ///
    /// No allocation occurs until the first push. The column is statically
    /// unique (no clone strategy exists for `~Copyable` elements; the wrapper
    /// cannot be duplicated).
    ///
    /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
    @inlinable
    public init(order: Order = .ascending) {
        self.order = order
        self._buffer = Shared(Column.Heap<Element>(minimumCapacity: .zero))
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

        /// Element storage: the `Shared` column over the fixed-capacity heap
        /// buffer (`Column.Bounded<Element>` = `Buffer.Linear.Bounded` over
        /// system-allocated contiguous storage).
        ///
        /// Conditional copyability flows from the column (`Shared<E, B>` is
        /// `Copyable` iff `E` is), and value semantics ride the ratified CoW
        /// box — the A-1 interim reshape (public element-generic API
        /// preserved; the hand-rolled `ensureUnique` CoW is deleted).
        @usableFromInline
        package var _buffer: Shared<Element, Column.Bounded<Element>>

        /// The ordering direction for this heap.
        public let order: Order

        /// The requested capacity (for overflow checking).
        ///
        /// The underlying storage may round its physical capacity up; this
        /// stored bound is the heap's contract — `push` rejects at exactly
        /// this count.
        public let requestedCapacity: Heap.Index.Count
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
    //
    // ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
    // (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
    // full template round.
    //
    // /// Double-ended priority queue backed by a binary min-max heap.
    // ///
    // /// Declared here (inside `Heap`) due to Swift's `~Copyable` constraint propagation rules.
    // /// All operations are implemented in the `Heap MinMax Primitive` / `Heap MinMax Primitives`
    // /// modules.
    // ///
    // /// See ``Heap/MinMax`` documentation for full API details.
    // // WHY: Category D — structural Sendable workaround; the type is
    // // WHY: structurally value-safe but the compiler cannot synthesize
    // // WHY: Sendable due to a stored pointer / generic parameter shape.
    // @safe
    // public struct MinMax: ~Copyable {
    //     @usableFromInline
    //     package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear
    //
    //     /// Creates an empty min-max heap.
    //     @inlinable
    //     public init() {
    //         self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear(minimumCapacity: .zero)
    //     }
    // }

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

// MARK: - Construction (Copyable twins — the clone-capturing sites)

// `Shared`'s constructors split on element copyability: the `Copyable` overload
// captures the column's deep-copy strategy so a shared box can restore
// uniqueness; the `~Copyable` overload captures none. The split must surface at
// HEAP construction too — a `Copyable`-element heap constructed through the
// `~Copyable` path would carry a box that cannot restore uniqueness. At
// `Copyable` call sites the more-constrained twin wins.

extension Heap where Element: Copyable {
    /// Creates an empty heap (CoW-capable column; the clone strategy is
    /// captured here).
    ///
    /// No allocation occurs until the first push.
    ///
    /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
    @inlinable
    public init(order: Order = .ascending) {
        self.order = order
        self._buffer = Shared(Column.Heap<Element>(minimumCapacity: .zero))
    }
}

// MARK: - Fixed Construction (Copyable twins — the clone-capturing sites)

// BOTH twins live in extensions (not the struct body): a struct-body member of
// the nested `Fixed` and a `where Element: Copyable` extension member mangle to
// the SAME symbol on 6.3.2 (the redundant-with-default `Copyable` requirement
// is dropped from the extension's mangled signature) — the extension/extension
// split is the coexisting spelling (the stack lane's catalog-B7 hazard).

extension Heap.Fixed where Element: ~Copyable {
    /// Creates an empty fixed-capacity heap of move-only elements.
    ///
    /// The column is statically unique (no clone strategy exists for
    /// `~Copyable` elements; the wrapper cannot be duplicated).
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of elements.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Heap/Fixed/Error/invalidCapacity`` if capacity is negative.
    @inlinable
    public init(
        capacity: Int,
        order: Heap.Order = .ascending
    ) throws(Heap.Fixed.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }
        // Boundary: Int → typed count. Cardinal(UInt(...)) is the canonical Int→Cardinal path.
        let requested = Heap.Index.Count(_unchecked: Cardinal(UInt(capacity)))
        self._buffer = Shared(Column.Bounded<Element>(minimumCapacity: requested))
        self.order = order
        self.requestedCapacity = requested
    }
}

extension Heap.Fixed where Element: Copyable {
    /// Creates an empty fixed-capacity heap (CoW-capable column; the
    /// CAPACITY-PRESERVING clone strategy is captured here — a shrink-to-fit
    /// copy would break the capacity contract after a CoW detach).
    ///
    /// - Parameters:
    ///   - capacity: Maximum number of elements.
    ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
    /// - Throws: ``Heap/Fixed/Error/invalidCapacity`` if capacity is negative.
    @inlinable
    public init(
        capacity: Int,
        order: Heap.Order = .ascending
    ) throws(Heap.Fixed.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }
        // Boundary: Int → typed count. Cardinal(UInt(...)) is the canonical Int→Cardinal path.
        let requested = Heap.Index.Count(_unchecked: Cardinal(UInt(capacity)))
        self._buffer = Shared(Column.Bounded<Element>(minimumCapacity: requested))
        self.order = order
        self.requestedCapacity = requested
    }
}

// MARK: - Conditional Copyable

/// `Heap` is `Copyable` when its elements are `Copyable`.
///
/// Copyability flows from the stored column: `Shared<Element, B>` is
/// `Copyable` exactly when `Element` is. Copies share the box until the first
/// mutation restores uniqueness (the `withUnique` gate).
extension Heap: Copyable where Element: Copyable {}

/// `Heap.Fixed` is `Copyable` when its elements are `Copyable`.
///
/// Copyability flows from the stored column (as on the base type); the CoW
/// detach clones CAPACITY-PRESERVINGLY.
extension Heap.Fixed: Copyable where Element: Copyable {}

// ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
// (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
// full template round.
// /// `Heap.MinMax` is `Copyable` when its elements are `Copyable`.
// extension Heap.MinMax: Copyable where Element: Copyable {}

// MARK: - Sendable

/// `Heap` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The stored `Shared` column is mutated exclusively through its uniqueness
/// gate (`withUnique` restores uniqueness FIRST), so a box shared between two
/// `Copyable`-element heap values is never written while shared — the stdlib
/// CoW-Sendable discipline. For `~Copyable` elements the heap is move-only:
/// at most one owner exists, and the box moves with it.
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
/// - Does not synchronize push/pop; mutation requires exclusive access to the
///   heap value itself.
extension Heap: @unsafe @unchecked Sendable where Element: Sendable {}

/// `Heap.Fixed` is `Sendable` when its elements are `Sendable`.
///
/// ## Safety Invariant
///
/// The stored `Shared` column is mutated exclusively through its uniqueness
/// gate (`withUnique` restores uniqueness FIRST), so a box shared between two
/// `Copyable`-element heap values is never written while shared — the stdlib
/// CoW-Sendable discipline. For `~Copyable` elements the heap is move-only:
/// at most one owner exists, and the box moves with it.
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
/// - Does not guarantee overflow safety under concurrent push; mutation
///   requires exclusive access to the heap value itself.
extension Heap.Fixed: @unsafe @unchecked Sendable where Element: Sendable {}

// ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
// (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
// full template round.
// /// Sendable conformance for `Heap.MinMax`.
// extension Heap.MinMax: @unsafe @unchecked Sendable where Element: Sendable {}

// MARK: - Push.Outcome Conditional Conformances

extension Heap.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Push.Outcome: Sendable where Element: Sendable {}
