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

public import Range_Primitives
public import Pointer_Primitives
public import Comparison_Primitives

extension Heap.Storage where Element: ~Copyable {

    /// Inline (stack-allocated) storage for small-buffer optimization.
    ///
    /// Provides the same element management API as `Heap.Storage` but for
    /// elements stored inline within a containing struct. Used by `Heap.Static`
    /// and `Heap.Small` for their inline storage needs.
    ///
    /// ## API Symmetry with Heap.Storage
    ///
    /// | Heap (`Heap.Storage`) | Inline (`Heap.Storage.Inline`) |
    /// |------------------------|--------------------------------|
    /// | `initialize(to:at:)` | `initialize(to:at:)` |
    /// | `move(at:)` | `move(at:)` |
    /// | `deinitialize(in:)` | `deinitialize(in:)` |
    /// | `move(to:count:)` | `move(to:count:)` |
    ///
    /// The inline variant requires `count` to be passed explicitly since it
    /// doesn't store count internally (the containing type manages count).
    @safe
    @usableFromInline
    package struct Inline<let capacity: Int>: ~Copyable {

        /// Raw byte storage (64 bytes per slot).
        @usableFromInline
        package var raw: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Maximum element stride supported (64 bytes).
        @inlinable
        package static var maxStride: Int { 64 }

        // MARK: - Lifecycle

        /// Creates uninitialized inline storage.
        ///
        /// - Precondition: Element stride must not exceed 64 bytes.
        /// - Precondition: Element alignment must not exceed `Int` alignment.
        @inlinable
        package init() {
            precondition(
                MemoryLayout<Element>.stride <= Self.maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self.maxStride) bytes)"
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment))"
            )
            self.raw = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
        }
    }
}

extension Heap.Storage.Inline where Element: ~Copyable {
    // MARK: - Scoped Pointer Access (Safe)

    /// Scoped mutable access to element at index.
    ///
    /// The pointer is only valid within the closure scope. This prevents
    /// pointer escape issues that occur with direct pointer returns.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a mutable pointer to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func withPointer<R: ~Copyable>(
        at index: Heap.Index,
        _ body: (Pointer<Element>.Mutable) -> R
    ) -> R {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            let ptr = unsafe Pointer<Element>.Mutable((base + (Heap.Index.Offset(index) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            return body(ptr)
        }
    }

    /// Scoped mutable access to two elements (for swap operations).
    ///
    /// - Parameters:
    ///   - i: The first index.
    ///   - j: The second index.
    ///   - body: A closure that receives mutable pointers to both elements.
    /// - Returns: The value returned by the closure.
    /// - Precondition: Both indices must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func withPointers<R: ~Copyable>(
        at i: Heap.Index, _ j: Heap.Index,
        _ body: (Pointer<Element>.Mutable, Pointer<Element>.Mutable) -> R
    ) -> R {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            let ptrI = unsafe Pointer<Element>.Mutable((base + (Heap.Index.Offset(i) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            let ptrJ = unsafe Pointer<Element>.Mutable((base + (Heap.Index.Offset(j) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            return body(ptrI, ptrJ)
        }
    }

    /// Scoped read-only access to element at index.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a read-only pointer to the element.
    /// - Returns: The value returned by the closure.
    /// - Precondition: Index must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func withReadPointer<R: ~Copyable>(
        at index: Heap.Index,
        _ body: (Pointer<Element>) -> R
    ) -> R {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeRawPointer(rawPointer)
            let ptr = unsafe Pointer<Element>((base + (Heap.Index.Offset(index) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            return body(ptr)
        }
    }

    /// Scoped read-only access to two elements (for comparison operations).
    ///
    /// - Parameters:
    ///   - i: The first index.
    ///   - j: The second index.
    ///   - body: A closure that receives read-only pointers to both elements.
    /// - Returns: The value returned by the closure.
    /// - Precondition: Both indices must be in bounds (caller's responsibility).
    @usableFromInline
    @unsafe
    package mutating func withReadPointers<R: ~Copyable>(
        at i: Heap.Index, _ j: Heap.Index,
        _ body: (Pointer<Element>, Pointer<Element>) -> R
    ) -> R {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeRawPointer(rawPointer)
            let ptrI = unsafe Pointer<Element>((base + (Heap.Index.Offset(i) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            let ptrJ = unsafe Pointer<Element>((base + (Heap.Index.Offset(j) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
            return body(ptrI, ptrJ)
        }
    }

    // MARK: - Convenience Operations

    /// Swaps elements at two indices.
    ///
    /// Encapsulates the move/initialize dance required for swapping ~Copyable elements.
    ///
    /// - Parameters:
    ///   - i: The first index.
    ///   - j: The second index.
    /// - Precondition: Both indices must be in bounds and initialized.
    @usableFromInline
    package mutating func swap(at i: Heap.Index, _ j: Heap.Index) {
        unsafe withPointers(at: i, j) { ptrI, ptrJ in
            let temp = ptrI.move()
            ptrI.initialize(to: ptrJ.move())
            ptrJ.initialize(to: temp)
        }
    }

    // MARK: - Element Initialization/Move

    /// Returns mutable pointer for internal use.
    ///
    /// Note: This returns an escaping pointer but is safe when used immediately
    /// in the same mutating function for initialize/move operations, because:
    /// 1. The mutating context provides exclusive access
    /// 2. The pointer is used immediately, not stored
    /// 3. No intervening operations occur that could invalidate it
    @usableFromInline
    @unsafe
    package mutating func _unsafePointer(at index: Heap.Index) -> Pointer<Element>.Mutable {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        return unsafe Swift.withUnsafeMutablePointer(to: &raw) { rawPointer in
            let base = UnsafeMutableRawPointer(rawPointer)
            return unsafe Pointer<Element>.Mutable((base + (Heap.Index.Offset(index) * stride).vector.rawValue).assumingMemoryBound(to: Element.self))
        }
    }

    /// Initializes element at the given index.
    ///
    /// - Parameters:
    ///   - element: The element to store (consumed).
    ///   - index: The index to initialize.
    /// - Precondition: The slot at index must be uninitialized.
    @usableFromInline
    package mutating func initialize(to element: consuming Element, at index: Heap.Index) {
        let ptr = unsafe _unsafePointer(at: index)
        ptr.initialize(to: element)
    }

    /// Moves element from the given index.
    ///
    /// - Parameter index: The index to move from.
    /// - Returns: The moved element.
    /// - Precondition: The slot at index must be initialized.
    /// - Postcondition: The slot at index is deinitialized.
    @usableFromInline
    package mutating func move(at index: Heap.Index) -> Element {
        unsafe _unsafePointer(at: index).move()
    }

    // MARK: - Bulk Operations

    /// Deinitializes elements in range.
    ///
    /// - Parameter range: The range of indices to deinitialize.
    /// - Precondition: All slots in range must be initialized.
    /// - Postcondition: All slots in range are deinitialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @usableFromInline
    package func deinitialize(in range: Range.Lazy<Heap.Index>) {
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
            range.forEach { index in
                unsafe (base + (Heap.Index.Offset(index) * stride).vector.rawValue)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
        }
    }

    /// Deinitializes all elements up to count.
    ///
    /// - Parameter count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Postcondition: All elements are deinitialized.
    /// - Note: Non-mutating to allow use from deinit contexts.
    @usableFromInline
    package func deinitialize(count: Heap.Index.Count) {
        guard count > .zero else { return }
        deinitialize(in: 0..<count)
    }

    /// Moves all elements to heap storage.
    ///
    /// Used when spilling from inline to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    /// - Postcondition: Elements are moved to heap, inline slots are deinitialized.
    @usableFromInline
    package mutating func move(to heapStorage: Heap.Storage, count: Heap.Index.Count) {
        guard count > .zero else { return }
        let stride = Affine.Discrete.Ratio<Element, UInt8>(MemoryLayout<Element>.stride)
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(rawPointer))
                (0..<count).forEach { index in
                    let src = unsafe (base + (Heap.Index.Offset(index) * stride).vector.rawValue).assumingMemoryBound(to: Element.self)
                    unsafe (dst + index).initialize(to: src.move())
                }
            }
        }
    }
}


// MARK: - Copyable Element Extensions

extension Heap.Storage.Inline where Element: Copyable {
    /// Copies all elements to heap storage.
    ///
    /// - Parameters:
    ///   - heapStorage: The destination heap storage.
    ///   - count: The number of initialized elements.
    /// - Precondition: Elements at indices 0..<count must be initialized.
    /// - Precondition: Heap storage must have sufficient capacity.
    @usableFromInline
    package func copy(to heapStorage: Heap.Storage, count: Heap.Index.Count) {
        guard count > .zero else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafePointer(to: raw) { rawPointer in
            unsafe heapStorage.withUnsafeMutablePointerToElements { dst in
                let base = unsafe UnsafeRawPointer(rawPointer)
                (0..<count).forEach { index in
                    let src = unsafe (base + index.position * stride).assumingMemoryBound(to: Element.self)
                    unsafe (dst + index).initialize(to: src.pointee)
                }
            }
        }
    }
}


// MARK: - Comparable Element Extensions

extension Heap.Storage.Inline where Element: ~Copyable & Comparison.`Protocol` {
    /// Compares elements at two indices using less-than.
    ///
    /// - Parameters:
    ///   - i: The first index.
    ///   - j: The second index.
    /// - Returns: `true` if the element at index `i` is less than the element at index `j`.
    /// - Precondition: Both indices must be in bounds and initialized.
    @usableFromInline
    package mutating func isLess(at i: Heap.Index, than j: Heap.Index) -> Bool {
        unsafe withReadPointers(at: i, j) { ptrI, ptrJ in
            ptrI.pointee < ptrJ.pointee
        }
    }
}
