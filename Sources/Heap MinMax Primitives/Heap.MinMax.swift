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
            self._cachedPtr = _storage._elementsPointer
        }
    }

    /// Compile-time capacity min-max heap with inline storage.
    public struct Static<let capacity: Int>: ~Copyable {
        @usableFromInline
        package static var _maxStride: Int { 64 }

        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _count: Int

        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline min-max heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride exceeds inline storage slot size"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment exceeds inline storage alignment"
            )
            self._storage = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = 0
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            let stride = MemoryLayout<Element>.stride

            unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(storagePtr))
                for i in 0..<count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }

        @usableFromInline
        @unsafe
        package mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        @usableFromInline
        @unsafe
        package func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
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
        @usableFromInline
        package static var _maxStride: Int { 64 }

        @usableFromInline
        package var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _count: Int

        @usableFromInline
        package var _heap: Heap<Element>.Storage?

        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small min-max heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride exceeds inline storage slot size"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment exceeds inline storage alignment"
            )
            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = 0
            self._heap = nil
            unsafe self._heapPtr = nil
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            if let heap = _heap {
                heap.header = count
            } else {
                let stride = MemoryLayout<Element>.stride
                unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                    let basePtr = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<count {
                        let elementPtr = unsafe (basePtr + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe elementPtr.deinitialize(count: 1)
                    }
                }
            }
        }

        @inlinable
        public var isSpilled: Bool { _heap != nil }

        @usableFromInline
        @unsafe
        package mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        @usableFromInline
        @unsafe
        package func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        @usableFromInline
        package mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heap == nil, "Already spilled")

            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)
            newStorage.header = _count

            let stride = MemoryLayout<Element>.stride
            _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = unsafe UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
                    for i in 0..<_count {
                        let inlineElement = unsafe (inlineBase + i * stride)
                            .assumingMemoryBound(to: Element.self)
                        unsafe (heapPtr + i).initialize(to: inlineElement.move())
                    }
                }
            }

            _heap = newStorage
            unsafe (_heapPtr = newStorage._elementsPointer)
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
