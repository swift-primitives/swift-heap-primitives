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

public import Heap_Primitives_Core
public import Property_Primitives
public import Range_Primitives

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

extension Heap.MinMax.Fixed: @unchecked Sendable where Element: Sendable {}
extension Heap.MinMax.Static: @unchecked Sendable where Element: Sendable {}
extension Heap.MinMax.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Error Type Aliases

extension Heap.MinMax {
    /// Errors that can occur during min-max heap operations.
    public typealias Error = __Heap.Error
}

extension Heap.MinMax.Fixed {
    /// Errors that can occur during fixed min-max heap operations.
    public typealias Error = __Heap.Fixed.Error
}

extension Heap.MinMax.Static {
    /// Errors that can occur during static min-max heap operations.
    public typealias Error = __Heap.Static.Error
}

extension Heap.MinMax.Small {
    /// Errors that can occur during small min-max heap operations.
    public typealias Error = __Heap.Small.Error
}


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
where Tag == Heap<Element>.MinMax.Remove,
      Base == Heap<Element>.MinMax,
      Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    ///   If `true`, the heap retains its current capacity.
    ///   If `false` (default), the capacity is released.
    /// - Complexity: O(n)
    @inlinable
    public func all(keepingCapacity: Bool = false) {
        let currentCount = unsafe base.pointee._storage.count
        if currentCount > .zero {
            unsafe base.pointee._storage.deinitialize(in: 0..<currentCount)
        }
        unsafe base.pointee._storage.header = 0

        if !keepingCapacity {
            unsafe base.pointee._storage = Heap.Storage.create()
            unsafe (base.pointee._cachedPtr = base.pointee._storage._elementsPointer)
        }
    }
}
