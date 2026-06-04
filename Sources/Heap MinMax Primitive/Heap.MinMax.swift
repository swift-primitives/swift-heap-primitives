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

// Note: Heap.MinMax is declared INSIDE the Heap struct body (in Heap.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// nested types and extensions for the MinMax heap.

public import Heap_Primitive
import Storage_Heap_Primitives
public import Buffer_Linear_Primitives
public import Property_Primitives

// MARK: - MinMax Nested Types

extension Heap.MinMax {
    /// Which position in the heap to operate on (min or max).
    public enum Position: Sendable, Equatable {
        /// The minimum element.
        case min
        /// The maximum element.
        case max
    }
}

// Note: Heap.MinMax.Fixed cannot have conditional Copyable conformance because
// it's a nested type declared in an extension. The ~Copyable constraint from
// Heap<Element> doesn't propagate properly to nested types in extensions.

// MARK: - Sendable

/// Sendable conformance for `Heap.MinMax.Fixed`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Fixed` is `~Copyable`. The Sendable claim rests on the same
/// unique-ownership argument as other `~Copyable` heap variants — transfer
/// via move relinquishes the sender's access.
///
/// ## Intended Use
///
/// - Fixed-capacity double-ended priority queue built then transferred
///   to a consuming actor or thread.
/// - Embedded scheduler workloads with bounded capacity requirements.
///
/// ## Non-Goals
///
/// - Not a concurrent min-max queue; external synchronization required.
extension Heap.MinMax.Fixed: @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Heap.MinMax.Static`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Static` is `~Copyable` with compile-time capacity and
/// inline storage. Single ownership guarantees cross-thread transfer is
/// sound; no heap allocation is involved.
///
/// ## Intended Use
///
/// - Stack-allocated double-ended priority queues transferred across
///   isolation boundaries during setup.
/// - Zero-allocation min-max heaps moved between phases of a pipeline.
///
/// ## Non-Goals
///
/// - Not shareable; inline storage is bound to the current owner.
/// - No cross-thread mutation; single-owner is the sole supported model.
extension Heap.MinMax.Static: @unchecked Sendable where Element: Sendable {}

/// Sendable conformance for `Heap.MinMax.Small`.
///
/// ## Safety Invariant
///
/// `Heap.MinMax.Small` is `~Copyable` with inline-plus-spill storage.
/// Unique ownership ensures the sender relinquishes access on move; the
/// inline bytes and any spilled heap allocation transfer as one unit.
///
/// ## Intended Use
///
/// - Small-size-optimized double-ended priority queues moved between
///   isolation domains.
///
/// ## Non-Goals
///
/// - Not a concurrent min-max queue.
/// - Spill transitions are not synchronized against external observers.
extension Heap.MinMax.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Error Type Aliases

extension Heap.MinMax {
    /// Errors that can occur during min-max heap operations.
    public typealias Error = Heap.Error
}

extension Heap.MinMax.Fixed {
    /// Errors that can occur during fixed min-max heap operations.
    public typealias Error = Heap.Fixed.Error
}

// Note: Heap.MinMax.Static and Heap.MinMax.Small define their own Error enums
// in their respective struct bodies because they have value generic parameters
// that would require explicit generic arguments when referencing the base types.

// MARK: - Property Typealias

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns (~Copyable).
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap.MinMax>
}

// MARK: - Remove Accessor

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    /// heap.remove.all()                      // Remove all, release capacity
    /// heap.remove.all(keepingCapacity: true) // Remove all, keep capacity
    /// ```
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.MinMax.Remove,
    Base == Heap<Element>.MinMax,
    Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    ///   If `true`, the heap retains its current capacity.
    ///   If `false` (default), the capacity is released.
    /// - Complexity: O(n)
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public func all(keepingCapacity: Bool = false) {
        base.value._buffer.remove.all()
        if !keepingCapacity {
            unsafe (base.value._buffer = Buffer<Storage<Element>.Heap>.Linear(minimumCapacity: .zero))
        }
    }
}
