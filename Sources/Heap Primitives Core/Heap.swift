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

    public typealias Pointer = Swift.UnsafeMutablePointer<Element>

    // MARK: - Order Enum

    /// Ordering direction for heap operations.
    public enum Order: Sendable, Hashable {
        /// Ascending order (min-heap): smallest element has highest priority.
        case ascending
        /// Descending order (max-heap): largest element has highest priority.
        case descending
    }

    // MARK: - Stored Properties

    /// The ordering direction for this heap.
    public let order: Order

    @usableFromInline
    package var _storage: Storage

    /// Cached pointer to element storage. Stored in struct to enable efficient access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    package var _cachedPtr: UnsafeMutablePointer<Element>

    // MARK: - Init

    /// Creates an empty heap with the specified ordering.
    ///
    /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
    @inlinable
    public init(order: Order = .ascending) {
        self.order = order
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    // Note: No deinit needed - Storage handles cleanup

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

    // MARK: - Fixed Capacity Heap

    public struct Fixed: ~Copyable {
        @usableFromInline
        package var _storage: Heap.Storage

        public let capacity: Int

        /// The ordering direction for this heap.
        public let order: Order

        @usableFromInline
        package var _cachedPtr: Pointer

        /// Creates an empty fixed-capacity heap.
        ///
        /// - Parameters:
        ///   - capacity: Maximum number of elements.
        ///   - order: The ordering direction. Defaults to `.ascending` (min-heap).
        /// - Throws: ``Fixed/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Int, order: Order = .ascending) throws(__Heap.Fixed.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }
            self._storage = Heap.Storage.create(minimumCapacity: capacity)
            self.capacity = capacity
            self.order = order
            self._cachedPtr = _storage._elementsPointer
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
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        package static var _maxStride: Int { 64 }

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        package var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        package var _count: Int

        /// The ordering direction for this heap.
        public let order: Order

        /// Workaround for Swift compiler bug.
        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
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
            self.order = order
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

    /// A binary heap with small-buffer optimization (SmallVec pattern).
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

        /// The ordering direction for this heap.
        public let order: Order

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        package var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
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
            self.order = order
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
        package var _storage: Heap.Storage

        /// Cached pointer to element storage.
        @usableFromInline
        package var _cachedPtr: UnsafeMutablePointer<Element>

        /// Creates an empty min-max heap.
        @inlinable
        public init() {
            self._storage = Heap.Storage.create()
            unsafe (self._cachedPtr = _storage._elementsPointer)
        }

        // Note: No deinit needed - Storage handles cleanup
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
extension Heap.Static.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Static.Push.Outcome: Sendable where Element: Sendable {}

// MARK: - Error Type Aliases

extension Heap {
    /// Errors that can occur during heap operations.
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
