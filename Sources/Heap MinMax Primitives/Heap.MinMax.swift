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

// MARK: - MinMax Nested Types

extension Heap.MinMax {
    /// Fixed-capacity min-max heap.
    @safe
    public struct Fixed: ~Copyable {
        @usableFromInline
        var _storage: Heap<Element>.Storage

        public let capacity: Int

        @usableFromInline
        package var _cachedPtr: Heap<Element>.Pointer

        /// Creates an empty fixed-capacity min-max heap.
        ///
        /// - Parameter capacity: Maximum number of elements.
        /// - Throws: Error if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(__Heap.Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._storage = Heap<Element>.Storage.create(minimumCapacity: capacity)
            self.capacity = capacity
            unsafe (self._cachedPtr = _storage._elementsPointer)
        }
    }

    /// Compile-time capacity min-max heap with inline storage.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Inline storage for elements.
        @usableFromInline
        package var inline: Heap<Element>.Storage.Inline<capacity>

        /// Current element count.
        public var count: Heap<Element>.Index.Count

        /// Workaround for Swift compiler bug.
        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline min-max heap.
        @inlinable
        public init() {
            self.inline = Heap<Element>.Storage.Inline<capacity>()
            self.count = .zero
        }

        deinit {
            inline.deinitialize(count: count)
        }

        public enum Push: ~Copyable {
            public enum Outcome: ~Copyable {
                case inserted
                case overflow(Element)
            }
        }
    }

    /// Min-max heap with small-buffer optimization.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Inline storage for elements.
        @usableFromInline
        package var inline: Heap<Element>.Storage.Inline<inlineCapacity>

        /// Current element count (valid elements in either inline or heap storage).
        public var count: Heap<Element>.Index.Count

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var heap: Heap<Element>.Storage?

        /// Cached pointer to heap elements. Only valid when heap is non-nil.
        @usableFromInline
        package var heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small min-max heap.
        @inlinable
        public init() {
            self.inline = Heap<Element>.Storage.Inline<inlineCapacity>()
            self.count = .zero
            self.heap = nil
            unsafe self.heapPtr = nil
        }

        deinit {
            guard count > .zero else { return }

            if let heapState = heap {
                heapState.header = count.rawValue
            } else {
                inline.deinitialize(count: count)
            }
        }

        /// Whether the heap is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { heap != nil }

        /// Spills inline storage to heap.
        @usableFromInline
        package mutating func spillToHeap(minimumCapacity: Int) {
            precondition(heap == nil, "Already spilled")

            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)
            newStorage.header = count.rawValue

            inline.move(to: newStorage, count: count)

            heap = newStorage
            unsafe (heapPtr = newStorage._elementsPointer)
        }
    }

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

// MARK: - Push Outcome Conformances

extension Heap.MinMax.Static.Push.Outcome: Sendable where Element: Sendable {}
