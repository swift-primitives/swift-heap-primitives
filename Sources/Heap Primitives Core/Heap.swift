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

// MARK: - Heap Namespace

/// Namespace for heap types.
///
/// The primary heap implementation is ``Heap/Binary``, a double-ended min-max heap.
/// For convenience, `Heap<Element>` can be used as a typealias for `Heap<Element>.Binary`
/// via the ``HeapOf`` typealias.
///
/// ## Variants
///
/// - ``Heap/Binary``: Dynamic, growable min-max heap
/// - ``Heap/Fixed``: Fixed capacity, heap-allocated
/// - ``Heap/Static``: Compile-time capacity, inline storage
/// - ``Heap/Small``: Small-buffer optimization
/// - ``Heap/Min``: Single-ended min-heap (stub)
/// - ``Heap/Max``: Single-ended max-heap (stub)
/// - ``Heap/MinMax``: Alternative double-ended (stub)
public struct Heap<Element: ~Copyable>: ~Copyable {

    public typealias Pointer = Swift.UnsafeMutablePointer<Element>
    
    // MARK: - Storage Class

    /// Internal storage class for Heap variants.
    ///
    /// Uses `ManagedBuffer` for efficient single-allocation storage.
    /// Declared inside `Heap` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type.
    @usableFromInline
    package final class Storage: ManagedBuffer<Int, Element> {

        /// Creates empty storage with no capacity.
        @usableFromInline
        package static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        /// Creates storage with the specified minimum capacity.
        @usableFromInline
        package static func create(minimumCapacity: Int) -> Storage {
            let requestedCapacity = Swift.max(minimumCapacity, 4)
            let storage = Storage.create(minimumCapacity: requestedCapacity) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        deinit {
            let count = header
            guard count > 0 else { return }
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in 0..<count {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        /// Returns pointer to element storage.
        @usableFromInline
        package var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        /// Initializes element at the given index.
        @usableFromInline
        package func _initializeElement(at index: Int, to element: consuming Element) {
            let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
            unsafe ptr.initialize(to: element)
        }

        /// Moves element from the given index.
        @usableFromInline
        package func _moveElement(at index: Int) -> Element {
            unsafe withUnsafeMutablePointerToElements { elements in
                unsafe (elements + index).move()
            }
        }

        /// Deinitializes elements in the given range.
        @usableFromInline
        package func _deinitializeElements(in range: Range<Int>) {
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in range {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        /// Moves all elements to new storage.
        @usableFromInline
        package func _moveAllElements(to newStorage: Storage, count: Int) {
            _ = unsafe withUnsafeMutablePointerToElements { old in
                unsafe newStorage.withUnsafeMutablePointerToElements { new in
                    unsafe new.moveInitialize(from: old, count: count)
                }
            }
        }
    }

    public struct Fixed: ~Copyable {
        @usableFromInline
        var _storage: Heap.Storage

        public let capacity: Int

        @usableFromInline
        package var _cachedPtr: Pointer {
            unsafe _storage.withUnsafeMutablePointerToElements { unsafe $0 }
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

    /// A fixed-capacity, inline-storage min-max heap with compile-time capacity.
    ///
    /// `Heap.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxStride: Int { 64 }

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _count: Int

        /// Workaround for Swift compiler bug.
        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Heap.Fixed instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Heap.Fixed instead."
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

        /// Returns a mutable pointer to the element at the given index.
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

        /// Returns a read-only pointer to the element at the given index.
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

        // MARK: - Push Outcome

        /// Outcome of a push operation on a static heap.
        public enum Push: ~Copyable {
            /// Outcome of pushing an element.
            public enum Outcome: ~Copyable {
                /// The element was successfully inserted.
                case inserted
                /// The heap was full; the element is returned to the caller.
                case overflow(Element)
            }
        }
    }

    // MARK: - Small (nested in body for value generic parameter per COPY-FIX-002)

    /// A min-max heap with small-buffer optimization (SmallVec pattern).
    ///
    /// `Heap.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxStride: Int { 64 }

        /// Raw byte storage for inline elements.
        @usableFromInline
        package var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid elements in either inline or heap storage).
        @usableFromInline
        package var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Heap.Fixed instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Heap.Fixed instead."
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

        /// Whether the heap is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heap != nil }

        /// Returns a mutable pointer to the inline element at the given index.
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

        /// Returns a read-only pointer to the inline element at the given index.
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

        /// Spills inline storage to heap.
        @usableFromInline
        package mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heap == nil, "Already spilled")

            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Storage.create(minimumCapacity: newCapacity)
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

    // MARK: - Position

    /// Which position in the heap to operate on (min or max).
    public enum Position: Sendable, Equatable {
        /// The minimum element.
        case min
        /// The maximum element.
        case max
    }

    // MARK: - Ordering Typealias

    /// Comparison protocol for heap elements.
    ///
    /// This is a typealias to `Comparison.Protocol` from comparison-primitives,
    /// which provides borrowing-based comparison for `~Copyable` types.
    public typealias Ordering = Comparison_Primitives.Comparison.`Protocol`
}

// MARK: - Copy-on-Write Storage Extensions (Copyable elements only)

extension Heap.Storage where Element: Copyable {
    /// Copies all elements to new storage (for CoW).
    @usableFromInline
    package func _copyAllElements(to newStorage: Heap.Storage, count: Int) {
        _ = unsafe withUnsafeMutablePointerToElements { old in
            unsafe newStorage.withUnsafeMutablePointerToElements { new in
                unsafe new.initialize(from: old, count: count)
            }
        }
    }

    /// Reads element at the given index.
    @usableFromInline
    package func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Writes element at the given index (assumes already initialized).
    @usableFromInline
    package func _writeElement(at index: Int, _ element: Element) {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements[index] = element)
        }
    }

    /// Swaps elements at two indices.
    @usableFromInline
    package func _swapElements(at i: Int, _ j: Int) {
        unsafe withUnsafeMutablePointerToElements { elements in
            let temp = unsafe elements[i]
            unsafe (elements[i] = elements[j])
            unsafe (elements[j] = temp)
        }
    }
}

// MARK: - Binary Min-Max Heap

extension Heap where Element: ~Copyable & Comparison.`Protocol` {
    /// Double-ended priority queue backed by a binary min-max heap.
    ///
    /// `Heap.Binary` provides O(1) access to both the minimum and maximum elements,
    /// with O(log n) insertion and removal. Based on min-max heaps
    /// (Atkinson et al. 1986).
    ///
    /// ## Move-Only Support
    ///
    /// `Heap.Binary` supports both `~Copyable` (move-only) and `Copyable` elements:
    ///
    /// ```swift
    /// // Move-only elements
    /// struct FileHandle: ~Copyable, Comparison.`Protocol` {
    ///     let fd: Int32
    ///
    ///     static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    ///         lhs.fd < rhs.fd
    ///     }
    ///
    ///     static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    ///         lhs.fd == rhs.fd
    ///     }
    /// }
    /// var handles = Heap<FileHandle>.Binary()  // ~Copyable heap
    ///
    /// // Copyable elements
    /// var ints = Heap<Int>.Binary()  // Copyable heap with CoW semantics
    /// ```
    ///
    /// ## API
    ///
    /// Operations use nested accessors (available for `Copyable` elements):
    ///
    /// ```swift
    /// var heap: Heap<Int>.Binary = [3, 1, 4, 1, 5]
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
    /// For `~Copyable` elements, use borrowing closures:
    ///
    /// ```swift
    /// heap.withMin { element in
    ///     print(element.fd)
    /// }
    /// ```
    ///
    /// ## Conditional Copyable
    ///
    /// `Heap.Binary` is `Copyable` when `Element: Copyable`, with copy-on-write semantics.
    ///
    /// ## Variants
    ///
    /// - ``Heap/Binary``: Dynamic, growable (this type)
    /// - ``Heap/Fixed``: Fixed capacity, heap-allocated
    /// - ``Heap/Static``: Compile-time capacity, inline storage
    /// - ``Heap/Small``: Small-buffer optimization
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
    @safe
    public struct Binary: ~Copyable {

        @usableFromInline
        package var _storage: Heap.Storage

        /// Cached pointer to element storage. Stored in struct to enable efficient access.
        /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        // MARK: - Init

        /// Creates an empty heap.
        @inlinable
        public init() {
            self._storage = Heap.Storage.create()
            unsafe (self._cachedPtr = _storage._elementsPointer)
        }

        // Note: No deinit needed - Storage handles cleanup

        // MARK: - Variant Typealiases

        /// Typealias for ``Heap/Fixed``.
        public typealias Fixed = Heap.Fixed

        /// Typealias for ``Heap/Static``.
        public typealias Static = Heap.Static

        /// Typealias for ``Heap/Small``.
        public typealias Small = Heap.Small
    }
}

// MARK: - Conditional Copyable

extension Heap.Binary: Copyable where Element: Copyable {}
extension Heap.Fixed: Copyable where Element: Copyable {}

// Note: Heap.Static is UNCONDITIONALLY ~Copyable due to deinit requirement.
// Note: Heap.Small is UNCONDITIONALLY ~Copyable due to deinit requirement.

// MARK: - Sendable

extension Heap.Binary: @unchecked Sendable where Element: Sendable {}
extension Heap.Fixed: @unchecked Sendable where Element: Sendable {}
extension Heap.Static: @unchecked Sendable where Element: Sendable {}
extension Heap.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Push.Outcome Conditional Conformances

extension Heap.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Push.Outcome: Sendable where Element: Sendable {}
extension Heap.Static.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Static.Push.Outcome: Sendable where Element: Sendable {}

// MARK: - Error Type Aliases

extension Heap.Binary {
    /// Errors that can occur during binary heap operations.
    public typealias Error = __Heap.Error
}

extension Heap.Fixed {
    /// Errors that can occur during fixed heap operations.
    public typealias Error = __Heap.Fixed.Error
}

extension Heap.Static {
    /// Errors that can occur during static heap operations.
    public typealias Error = __Heap.Static.Error
}

extension Heap.Small {
    /// Errors that can occur during small heap operations.
    public typealias Error = __Heap.Small.Error
}
