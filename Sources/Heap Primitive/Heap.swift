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

// MARK: - Heap (the ADT tier — a binary MIN priority queue over the COLUMN)
//
// ADT Tower W2 reshape (Research/adt-tower.md §9.3 heap row, adt-tower.md:1246;
// SEAT+principal ratified 2026-07-02). The worked example
// (Experiments/adt-tower-worked-example/Sources/HeapKit/Heap.swift) IS the
// blueprint — ops verbatim-portable:
//   1. thin bound-free carrier `__Heap<S: ~Copyable>` (hoisted per
//      [API-IMPL-009]/[PKG-NAME-006]; public spelling is the front-door alias
//      `Heap<E>` in Heap.FrontDoor.swift, [DS-028]);
//   2. semantic ops written ONCE over the Store/Buffer seams (the [DS-024]
//      ledger laws keep `count` honest through them), CoW-correct via
//      `unshare()`, FULL ~Copyable element support via
//      `Comparison.Protocol`;
//   3. growth written ONCE, pinned to the linear column GENERIC over the
//      allocation (`Resource: Memory.Growable` — the [DS-029] form-2 re-point;
//      heap rides `Buffer.Linear`, so the R-generic pin is the shipped surface).
//
// The prior shape-E core (2,676 LOC: runtime `order:` axis, `Shared`-CoW-default,
// Min/Max stubs, Builder/Navigate) is REPLACED. The canonical `Heap<E>` is the
// DIRECT move-only heap column; `Shared` (CoW) returns only consumer-pulled as a
// `.Shared` front-door variant. Max-heap is dropped from the public surface
// (min-only canonical — ratified). `Heap.MinMax` stays PARKED as a future
// sibling for the heap-template round (its source is retained in-tree, out of
// the build graph — unchanged plan).

public import Comparison_Primitives
public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Index_Primitives

// MARK: 1. The carrier (thin, bound-free; hoisted per [API-IMPL-009])

/// A binary min priority queue — the semantic ADT over an explicit storage COLUMN.
///
/// `__Heap` is the bound-free carrier ([DS-025]): its column parameter `S` is bound
/// `~Copyable` **only**; every capability (observability, the seam element ops,
/// construction/growth) attaches by conditional `@inlinable` extension keyed on the
/// seams the column conforms (D3). The PUBLIC spelling of the family is the front-door
/// alias `Heap<E>` (canonical), declared in `Heap.FrontDoor.swift` ([DS-028]); the
/// hoisted name never appears in consumer signatures.
///
/// Copyability flows from the column: `__Heap<S>` is `Copyable` exactly when `S` is
/// (the default direct column is move-only by design; the `Shared` CoW column, when a
/// consumer pulls it, is `Copyable` iff its element is).
@_documentation(visibility: public)   // symbolgraph-extract drops __-prefixed decls otherwise
@frozen
public struct __Heap<S: ~Copyable>: ~Copyable {

    /// The storage column — a move-only buffer (the default ownership column) or a
    /// `Shared` CoW column. The ADT is a thin semantic discipline over it; it carries
    /// NO deinit (teardown lives in the leaf's oracle / the shared box's drain).
    @usableFromInline
    package var column: S

    /// Wraps an existing column.
    @inlinable
    public init(column: consuming S) { self.column = column }

    /// Consumes the heap, yielding its storage column.
    @inlinable
    public consuming func take() -> S { column }
}

extension __Heap: Copyable where S: Copyable {}
extension __Heap: Sendable where S: Sendable & ~Copyable {}

// MARK: 2. Semantic ops — written ONCE over the seams (any conforming column)

extension __Heap where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public var count: Index<S.Element>.Count { column.count }

    @inlinable
    public var isEmpty: Bool { column.isEmpty }

    /// Borrowing access to the minimum element.
    ///
    /// Precondition-gated (traps on empty), NOT Optional-returning: there is no
    /// Optional *borrow* of a `~Copyable` element (an `Element?` borrow is
    /// structurally unavailable), so `min` cannot vend `Element?` by borrow —
    /// unlike `pop`, which consumes and returns `Element?`. Guard with `isEmpty`.
    ///
    /// - Precondition: The heap must not be empty.
    @inlinable
    public var min: S.Element {
        _read { yield column[0] }
    }
}

extension __Heap where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Element: Comparison.`Protocol` {

    /// Runtime slot coordinate (heap-order arithmetic happens in raw `Int`).
    @inlinable
    func slot(_ k: Int) -> Index<S.Element> {
        Index(Ordinal(UInt(k)))
    }

    /// Exchanges two initialized slots through the seam's move/initialize transitions.
    ///
    /// - Precondition: the caller must have gated `unshare()` (CoW
    ///   uniqueness) before invoking — this helper mutates the column in place.
    @inlinable
    mutating func exchange(_ i: Index<S.Element>, _ j: Index<S.Element>) {
        let a = column.move(at: i)
        let b = column.move(at: j)
        column.initialize(at: i, to: b)
        column.initialize(at: j, to: a)
    }

    /// Restores the heap invariant upward from raw slot `k`.
    ///
    /// - Precondition: the caller must have gated `unshare()` (CoW
    ///   uniqueness) before invoking — this helper mutates the column in place.
    @inlinable
    mutating func siftUp(from k: Int) {
        var child = k
        while child > 0 {
            let parent = (child - 1) / 2
            if column[slot(child)] < column[slot(parent)] {
                exchange(slot(child), slot(parent))
                child = parent
            } else { break }
        }
    }

    /// Restores the heap invariant downward from the root over `n` live slots.
    ///
    /// - Precondition: the caller must have gated `unshare()` (CoW
    ///   uniqueness) before invoking — this helper mutates the column in place.
    @inlinable
    mutating func siftDown(over n: Int) {
        var parent = 0
        while true {
            let l = 2 * parent + 1
            let r = l + 1
            var smallest = parent
            if l < n, column[slot(l)] < column[slot(smallest)] { smallest = l }
            if r < n, column[slot(r)] < column[slot(smallest)] { smallest = r }
            if smallest == parent { return }
            exchange(slot(parent), slot(smallest))
            parent = smallest
        }
    }

    /// Removes and returns the minimum element, or `nil` if the heap is empty
    /// (seam-generic; no growth involved).
    ///
    /// Returns `Element?` — the tower-wide remove-from-empty convention
    /// (adt-tower.md:1247; the landed `Queue.dequeue()` model). This supersedes
    /// both the shape-E `throws(Heap.Error)` and the worked example's crashing
    /// precondition (the experiment stays frozen; only the in-tree reshape adopts
    /// the Optional return). Consuming an `Element?` is available even for
    /// `~Copyable` elements (unlike a borrow — see `min`).
    @inlinable
    public mutating func pop() -> S.Element? {
        let n = Int(clamping: count)
        if n == 0 { return nil }
        column.unshare()
        if n == 1 { return column.move(at: slot(0)) }
        let root = column.move(at: slot(0))
        let last = column.move(at: slot(n - 1))
        column.initialize(at: slot(0), to: last)
        siftDown(over: n - 1)
        return root
    }
}

// MARK: 3. Growth — written ONCE, allocation-GENERIC ([DS-029] form-2 R-generic pin)

extension __Heap where S: ~Copyable {

    /// Creates an empty heap on any growable linear column.
    @inlinable
    public init<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        minimumCapacity: Index<E>.Count = Index<E>.Count(4)
    ) where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        self.init(column: S(minimumCapacity: minimumCapacity))
    }

    /// Inserts an element (grow-if-full rides the column's own R-generic append).
    @inlinable
    public mutating func push<E: ~Copyable & Comparison.`Protocol`, Resource: Memory.Growable & ~Copyable>(
        _ element: consuming E
    ) where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        column.append(element)
        siftUp(from: Int(clamping: count) - 1)
    }
}
