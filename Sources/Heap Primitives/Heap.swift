// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Double-ended priority queue backed by a min-max heap.
///
/// `Heap` provides O(1) access to both the minimum and maximum elements,
/// with O(log n) insertion and removal. Based on min-max heaps
/// (Atkinson et al. 1986).
///
/// ## Move-Only Support
///
/// `Heap` supports both `~Copyable` (move-only) and `Copyable` elements:
///
/// ```swift
/// // Move-only elements
/// struct FileHandle: ~Copyable, Heap.Ordering {
///     let fd: Int32
///     static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
///         lhs.fd < rhs.fd
///     }
/// }
/// var handles = Heap<FileHandle>()  // ~Copyable heap
///
/// // Copyable elements
/// var ints = Heap<Int>()  // Copyable heap with CoW semantics
/// ```
///
/// ## API
///
/// Operations use nested accessors (available for `Copyable` elements):
///
/// ```swift
/// var heap: Heap<Int> = [3, 1, 4, 1, 5]
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
/// `Heap` is `Copyable` when `Element: Copyable`, with copy-on-write semantics.
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
public struct Heap<Element: ~Copyable & __HeapOrdering>: ~Copyable {

    // MARK: - Unified Storage (nested to inherit Element's ~Copyable context)

    /// Internal storage class for Heap.
    ///
    /// Uses `ManagedBuffer` for efficient single-allocation storage.
    /// Declared as a nested class inside `Heap` so that the `Element` generic
    /// inherits the `~Copyable` suppression from the outer type.
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {

        /// Creates empty storage with no capacity.
        @usableFromInline
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 0) { _ in 0 }
            return unsafe unsafeDowncast(storage, to: Storage.self)
        }

        /// Creates storage with the specified minimum capacity.
        @usableFromInline
        static func create(minimumCapacity: Int) -> Storage {
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
        var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        /// Initializes element at the given index.
        @usableFromInline
        func _initializeElement(at index: Int, to element: consuming Element) {
            let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
            unsafe ptr.initialize(to: element)
        }

        /// Moves element from the given index.
        @usableFromInline
        func _moveElement(at index: Int) -> Element {
            unsafe withUnsafeMutablePointerToElements { elements in
                unsafe (elements + index).move()
            }
        }

        /// Deinitializes elements in the given range.
        @usableFromInline
        func _deinitializeElements(in range: Range<Int>) {
            _ = unsafe withUnsafeMutablePointerToElements { elements in
                for i in range {
                    unsafe (elements + i).deinitialize(count: 1)
                }
            }
        }

        /// Moves all elements to new storage.
        @usableFromInline
        func _moveAllElements(to newStorage: Storage, count: Int) {
            _ = unsafe withUnsafeMutablePointerToElements { old in
                unsafe newStorage.withUnsafeMutablePointerToElements { new in
                    unsafe new.moveInitialize(from: old, count: count)
                }
            }
        }
    }

    @usableFromInline
    var _storage: Storage

    /// Cached pointer to element storage. Stored in struct to enable efficient access.
    /// CRITICAL: Must be updated whenever _storage is replaced (reallocation, CoW copy).
    @usableFromInline
    var _cachedPtr: UnsafeMutablePointer<Element>

    // MARK: - Initialization

    /// Creates an empty heap.
    @inlinable
    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    // Note: No deinit needed - Storage handles cleanup

    // MARK: - Bounded (declared here to fix Swift compiler bug with ~Copyable in extensions)

    /// A fixed-capacity, heap-allocated min-max heap with bounded capacity.
    ///
    /// `Heap.Bounded` allocates storage upfront and uses token-preserving `Outcome`
    /// types for push operations that can overflow. This ensures elements are never
    /// lost on failure per [API-ERR-005/006].
    ///
    /// ## Example
    ///
    /// ```swift
    /// var heap = try Heap<Int>.Bounded(capacity: 10)
    /// switch heap.push(42) {
    /// case .inserted:
    ///     print("Element inserted")
    /// case .overflow(let element):
    ///     print("Overflow - element \(element) returned")
    /// }
    /// ```
    ///
    /// ## Overflow Handling
    ///
    /// Unlike variants that throw on overflow, `Heap.Bounded` returns an `Outcome`
    /// that preserves the element:
    ///
    /// - `.inserted`: Element was successfully added
    /// - `.overflow(Element)`: Heap was full, element returned to caller
    ///
    /// This pattern prevents element loss when pushing `~Copyable` types.
    @safe
    public struct Bounded: ~Copyable {
        @usableFromInline
        var _storage: Storage

        /// Cached pointer to element storage.
        @usableFromInline
        var _cachedPtr: UnsafeMutablePointer<Element>

        /// The maximum number of elements the heap can hold.
        public let capacity: Int

        /// Creates a heap with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of elements. Must be non-negative.
        /// - Throws: ``Heap/Bounded/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Int) throws(__Heap.Bounded.Error) {
            guard capacity >= 0 else {
                throw .invalidCapacity
            }

            self._storage = Storage.create(minimumCapacity: capacity)
            unsafe (self._cachedPtr = _storage._elementsPointer)
            self.capacity = capacity
        }

        // Note: No deinit needed - Storage handles cleanup

        // MARK: - Push Outcome (declared in struct body per MEM-COPY-006)

        /// Outcome of a push operation on a bounded heap.
        ///
        /// This type preserves the element on overflow, preventing element loss
        /// when pushing `~Copyable` types per [API-ERR-005/006].
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

    // MARK: - Inline (declared here to fix Swift compiler bug with ~Copyable in extensions)

    /// A fixed-capacity, inline-storage min-max heap with compile-time capacity.
    ///
    /// `Heap.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var heap = Heap<Int>.Inline<8>()
    /// switch heap.push(42) {
    /// case .inserted:
    ///     print("Element inserted")
    /// case .overflow(let element):
    ///     print("Overflow - element \(element) returned")
    /// }
    /// ```
    ///
    /// - Note: This type is declared inside `Heap` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    public struct Inline<let capacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Raw byte storage. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        @usableFromInline
        var _count: Int

        /// Workaround for Swift compiler bug where deinit element cleanup
        /// fails for ~Copyable structs that contain only value-type properties.
        /// Adding a reference type property (`AnyObject?`) fixes the bug.
        /// See: https://github.com/swiftlang/swift/issues/86652
        @usableFromInline
        var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Heap.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Heap.Bounded instead."
            )
            self._storage = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = 0
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            let stride = MemoryLayout<Element>.stride

            unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(storagePtr))
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
        mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
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
        func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
            let stride = MemoryLayout<Element>.stride
            return unsafe Swift.withUnsafePointer(to: _storage) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr
            }
        }

        // MARK: - Push Outcome (declared in struct body per MEM-COPY-006)

        /// Outcome of a push operation on an inline heap.
        ///
        /// This type preserves the element on overflow, preventing element loss
        /// when pushing `~Copyable` types per [API-ERR-005/006].
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

    // MARK: - Small (declared here to fix Swift compiler bug with ~Copyable in extensions)

    /// A min-max heap with small-buffer optimization (SmallVec pattern).
    ///
    /// `Heap.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    /// Push operations never fail - the heap grows automatically.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var heap = Heap<Int>.Small<4>()  // Inline up to 4 elements
    /// heap.push(1)  // Inline
    /// heap.push(2)  // Inline
    /// heap.push(3)  // Inline
    /// heap.push(4)  // Inline
    /// heap.push(5)  // Spills to heap, moves all elements
    /// ```
    ///
    /// ## Non-Copyable
    ///
    /// `Heap.Small` is unconditionally `~Copyable` (move-only) because it requires
    /// a deinitializer to clean up inline storage.
    ///
    /// - Note: This type is declared inside `Heap` (not in an extension) due to a
    ///   Swift compiler bug where nested types with value generic parameters declared
    ///   in extensions do not properly inherit `~Copyable` constraints from the outer type.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Maximum element stride supported by inline storage (64 bytes per slot).
        @usableFromInline
        static var _maxStride: Int { 64 }

        /// Raw byte storage for inline elements. Each slot is 64 bytes (8 Ints on 64-bit).
        @usableFromInline
        var _inline: InlineArray<inlineCapacity, (Int, Int, Int, Int, Int, Int, Int, Int)>

        /// Current element count (valid elements in either inline or heap storage).
        @usableFromInline
        var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        var _heap: Storage?

        /// Cached pointer to heap elements. Only valid when _heap is non-nil.
        @usableFromInline
        var _heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small heap.
        @inlinable
        public init() {
            precondition(
                MemoryLayout<Element>.stride <= Self._maxStride,
                "Element stride (\(MemoryLayout<Element>.stride)) exceeds inline storage slot size (\(Self._maxStride) bytes). Use Heap.Bounded instead."
            )
            precondition(
                MemoryLayout<Element>.alignment <= MemoryLayout<Int>.alignment,
                "Element alignment (\(MemoryLayout<Element>.alignment)) exceeds inline storage alignment (\(MemoryLayout<Int>.alignment)). Use Heap.Bounded instead."
            )
            self._inline = InlineArray(repeating: (0, 0, 0, 0, 0, 0, 0, 0))
            self._count = 0
            self._heap = nil
            self._heapPtr = nil
        }

        deinit {
            let count = _count
            guard count > 0 else { return }

            if let heap = _heap {
                // Elements are on heap - Storage handles cleanup via its deinit
                heap.header = count
            } else {
                // Elements are inline - clean up manually
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

        // MARK: - Internal Helpers

        /// Returns a mutable pointer to the inline element at the given index.
        @usableFromInline
        @unsafe
        mutating func _inlinePointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
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
        func _inlineReadPointerToElement(at index: Int) -> UnsafePointer<Element> {
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
        mutating func _spillToHeap(minimumCapacity: Int) {
            precondition(_heap == nil, "Already spilled")

            // Create heap storage with growth factor
            let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
            let newStorage = Storage.create(minimumCapacity: newCapacity)
            newStorage.header = _count

            // Move elements from inline to heap
            let stride = MemoryLayout<Element>.stride
            _ = unsafe Swift.withUnsafeBytes(of: _inline) { bytes in
                unsafe newStorage.withUnsafeMutablePointerToElements { heapPtr in
                    let inlineBase = UnsafeMutableRawPointer(mutating: bytes.baseAddress!)
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
}

// MARK: - Conditional Copyable

extension Heap: Copyable where Element: Copyable {}

/// `Heap.Bounded` is `Copyable` when its elements are `Copyable`.
extension Heap.Bounded: Copyable where Element: Copyable {}

// Note: Heap.Inline is UNCONDITIONALLY ~Copyable due to deinit requirement for inline storage cleanup.

// Note: Heap.Small is UNCONDITIONALLY ~Copyable due to deinit requirement for inline storage cleanup.

// MARK: - Sendable

extension Heap: @unchecked Sendable where Element: Sendable {}
extension Heap.Bounded: @unchecked Sendable where Element: Sendable {}
extension Heap.Inline: @unchecked Sendable where Element: Sendable {}
extension Heap.Small: @unchecked Sendable where Element: Sendable {}

// MARK: - Push.Outcome Conditional Conformances (per MEM-COPY-006)
extension Heap.Bounded.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Bounded.Push.Outcome: Sendable where Element: Sendable {}
extension Heap.Inline.Push.Outcome: Copyable where Element: Copyable {}
extension Heap.Inline.Push.Outcome: Sendable where Element: Sendable {}

// MARK: - Heap.Node Comparable (per MEM-COPY-006)
// Protocol conformances for nested types MUST be in the same file as the outer type.

extension Heap.Node: Comparable where Element: ~Copyable {
    @inlinable
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.offset == rhs.offset
    }

    @inlinable
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.offset < rhs.offset
    }
}

// MARK: - Error Type Aliases

extension Heap.Bounded {
    /// Errors that can occur during bounded heap operations.
    public typealias Error = __Heap.Bounded.Error
}

extension Heap.Inline {
    /// Errors that can occur during inline heap operations.
    public typealias Error = __Heap.Inline.Error
}

extension Heap.Small {
    /// Errors that can occur during small heap operations.
    public typealias Error = __Heap.Small.Error
}

// MARK: - Ordering Typealias

extension Heap {
    /// Comparison protocol for heap elements.
    ///
    /// Due to Swift's limitation on nesting protocols in generic contexts,
    /// the actual protocol is hoisted to module level as `__HeapOrdering`.
    ///
    /// ## Usage
    ///
    /// For `~Copyable` types:
    /// ```swift
    /// struct UniqueResource: ~Copyable, Heap.Ordering {
    ///     let priority: Int
    ///     static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    ///         lhs.priority < rhs.priority
    ///     }
    /// }
    /// ```
    ///
    /// For `Comparable` types, conformance is automatic via bridge:
    /// ```swift
    /// extension MyType: Heap.Ordering {}  // Uses < operator
    /// ```
    public typealias Ordering = __HeapOrdering
}

// MARK: - Properties

extension Heap where Element: ~Copyable {
    /// The number of elements in the heap.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }
}

// MARK: - Capacity Management

extension Heap where Element: ~Copyable {
    /// Ensures the storage has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func _ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header

        _storage._moveAllElements(to: newStorage, count: currentCount)
        newStorage.header = currentCount
        _storage.header = 0  // Prevent double-free

        _storage = newStorage
        unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
    }

    /// Reserves enough space to store the specified number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum number of elements.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        _ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (Internal)

extension Heap where Element: ~Copyable {
    /// Appends element without maintaining heap property (for bulk init).
    @usableFromInline
    mutating func _appendWithoutHeapify(_ element: consuming Element) {
        _ensureCapacity(_storage.header + 1)
        let index = _storage.header
        _storage._initializeElement(at: index, to: element)
        _storage.header += 1
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    mutating func _insert(_ element: consuming Element) {
        _ensureCapacity(_storage.header + 1)
        let index = _storage.header
        _storage._initializeElement(at: index, to: element)
        _storage.header += 1
        _bubbleUp(Node(offset: index))
    }

    /// Removes and returns the minimum element.
    @usableFromInline
    mutating func _removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage._moveElement(at: 0)
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _storage.header - 1
        _swapElements(at: 0, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)
        _trickleDownMin(Node.root)
        return removed
    }

    /// Removes and returns the maximum element.
    @usableFromInline
    mutating func _removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _storage.header = 0
            return _storage._moveElement(at: 0)
        }

        if count == 2 {
            _storage.header = 1
            return _storage._moveElement(at: 1)
        }

        // Find max (at index 1 or 2) using isLessThan
        let ptr = unsafe _cachedPtr
        let maxIndex = Element.isLessThan(unsafe ptr[1], unsafe ptr[2]) ? 2 : 1

        // Swap with last, remove last, trickle down
        let lastIndex = _storage.header - 1
        _swapElements(at: maxIndex, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)

        if maxIndex < _storage.header {
            _trickleDownMax(Node(offset: maxIndex, level: 1))
        }

        return removed
    }

    /// Swaps elements at two indices using the cached pointer.
    @usableFromInline
    mutating func _swapElements(at i: Int, _ j: Int) {
        let ptr = unsafe _cachedPtr
        let temp = unsafe (ptr + i).move()
        unsafe (ptr + i).initialize(to: (ptr + j).move())
        unsafe (ptr + j).initialize(to: temp)
    }
}

// MARK: - Public Mutating Operations

extension Heap where Element: ~Copyable {
    /// Inserts an element into the heap.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func push(_ element: consuming Element) {
        _insert(element)
    }

    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        let currentCount = _storage.header
        if currentCount > 0 {
            _storage._deinitializeElements(in: 0..<currentCount)
        }
        _storage.header = 0

        if !keepingCapacity {
            _storage = Storage.create()
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap where Element: ~Copyable {
    /// Provides borrowing access to the minimum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the minimum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return body(unsafe _cachedPtr[0])
    }

    /// Provides borrowing access to the maximum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the maximum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return body(unsafe _cachedPtr[0]) }
        if count == 2 { return body(unsafe _cachedPtr[1]) }

        let ptr = unsafe _cachedPtr
        let maxIndex = Element.isLessThan(unsafe ptr[1], unsafe ptr[2]) ? 2 : 1
        return body(unsafe ptr[maxIndex])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// Note: This is heap order, not sorted order.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        let ptr = unsafe _cachedPtr
        for i in 0..<count {
            body(unsafe ptr[i])
        }
    }
}

// MARK: - Bubble Up

extension Heap where Element: ~Copyable {
    /// Restores heap property by moving element up.
    @usableFromInline
    mutating func _bubbleUp(_ node: Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let ptr = unsafe _cachedPtr

        // Compare using Element.isLessThan with borrowing
        let nodeIsLess = Element.isLessThan(unsafe ptr[node.offset], unsafe ptr[parent.offset])
        let parentIsLess = Element.isLessThan(unsafe ptr[parent.offset], unsafe ptr[node.offset])

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            _swapElements(at: node.offset, parent.offset)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = Element.isLessThan(unsafe ptr[grandparent.offset], unsafe ptr[node.offset])
                guard !gpIsLess else { break }  // node < grandparent
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = Element.isLessThan(unsafe ptr[node.offset], unsafe ptr[grandparent.offset])
                guard !nodeIsLessGp else { break }  // node > grandparent
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap where Element: ~Copyable {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMin(_ startNode: Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            // Find smallest among children and grandchildren
            var smallest = node
            var smallestOffset = node.offset

            // Check children
            let rightChild = node.rightChild()

            if Element.isLessThan(unsafe ptr[leftChild.offset], unsafe ptr[smallestOffset]) {
                smallest = leftChild
                smallestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if Element.isLessThan(unsafe ptr[rightChild.offset], unsafe ptr[smallestOffset]) {
                    smallest = rightChild
                    smallestOffset = rightChild.offset
                }
            }

            // Check grandchildren
            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if Element.isLessThan(unsafe ptr[gcOffset], unsafe ptr[smallestOffset]) {
                    smallest = Node(offset: gcOffset, level: gc0.level)
                    smallestOffset = gcOffset
                }
            }

            if smallest.offset == node.offset { break }

            _swapElements(at: node.offset, smallest.offset)

            // If swapped with grandchild, may need to swap with parent
            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if Element.isLessThan(unsafe ptr[parent.offset], unsafe ptr[smallest.offset]) {
                    _swapElements(at: smallest.offset, parent.offset)
                }
                node = smallest
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap where Element: ~Copyable {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMax(_ startNode: Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            // Find largest among children and grandchildren
            var largest = node
            var largestOffset = node.offset

            // Check children
            let rightChild = node.rightChild()

            // largest < leftChild means leftChild > largest
            if Element.isLessThan(unsafe ptr[largestOffset], unsafe ptr[leftChild.offset]) {
                largest = leftChild
                largestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if Element.isLessThan(unsafe ptr[largestOffset], unsafe ptr[rightChild.offset]) {
                    largest = rightChild
                    largestOffset = rightChild.offset
                }
            }

            // Check grandchildren
            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if Element.isLessThan(unsafe ptr[largestOffset], unsafe ptr[gcOffset]) {
                    largest = Node(offset: gcOffset, level: gc0.level)
                    largestOffset = gcOffset
                }
            }

            if largest.offset == node.offset { break }

            _swapElements(at: node.offset, largest.offset)

            // If swapped with grandchild, may need to swap with parent
            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                // newValue < parentValue
                if Element.isLessThan(unsafe ptr[largest.offset], unsafe ptr[parent.offset]) {
                    _swapElements(at: largest.offset, parent.offset)
                }
                node = largest
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify (Floyd's Algorithm)

extension Heap where Element: ~Copyable {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    mutating func _heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        let limit = count / 2

        var level = Node.level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = Node.firstNode(onLevel: level)
            let lastOnLevel = Node.lastNode(onLevel: level)

            let startOffset = firstOnLevel.offset
            let endOffset = Swift.min(lastOnLevel.offset, limit - 1)

            if Node.isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(Node(offset: offset, level: level))
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(Node(offset: offset, level: level))
                }
            }
            level -= 1
        }
    }
}

// Note: Sendable conformances are declared earlier in the file with the other conformances.

// =============================================================================
// MARK: - Copyable-Only Extensions
// =============================================================================

// MARK: - Sequence Init (Copyable only)

extension Heap where Element: Copyable {
    /// Creates a heap from a sequence using O(n) heapification.
    ///
    /// - Parameter elements: The sequence of elements.
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)

        for element in elements {
            _appendWithoutHeapify(element)
        }

        if _storage.header > 1 {
            _heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap.Storage where Element: Copyable {
    /// Copies all elements to new storage (for CoW).
    @usableFromInline
    func _copyAllElements(to newStorage: Heap.Storage, count: Int) {
        _ = unsafe withUnsafeMutablePointerToElements { old in
            unsafe newStorage.withUnsafeMutablePointerToElements { new in
                unsafe new.initialize(from: old, count: count)
            }
        }
    }
}

extension Heap where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Storage.create(minimumCapacity: _storage.capacity)
            let currentCount = _storage.header
            _storage._copyAllElements(to: newStorage, count: currentCount)
            newStorage.header = currentCount
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)  // CRITICAL: Update cached pointer
        }
    }
}

// MARK: - CoW-aware Public Operations (Copyable only)

extension Heap where Element: Copyable {
    /// Inserts an element into the heap (CoW-aware).
    ///
    /// This method shadows the base `push(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    ///
    /// - Parameter element: The element to insert.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func push(_ element: Element) {
        _makeUnique()
        _insert(element)
    }

}

// MARK: - Peek/Read Operations (Copyable only)

extension Heap.Storage where Element: Copyable {
    /// Reads element at the given index.
    @usableFromInline
    func _readElement(at index: Int) -> Element {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe elements[index]
        }
    }

    /// Writes element at the given index (assumes already initialized).
    @usableFromInline
    func _writeElement(at index: Int, _ element: Element) {
        unsafe withUnsafeMutablePointerToElements { elements in
            unsafe (elements[index] = element)
        }
    }

    /// Swaps elements at two indices.
    @usableFromInline
    func _swapElements(at i: Int, _ j: Int) {
        unsafe withUnsafeMutablePointerToElements { elements in
            let temp = unsafe elements[i]
            unsafe (elements[i] = elements[j])
            unsafe (elements[j] = temp)
        }
    }
}

extension Heap where Element: Copyable {
    /// Returns the minimum element without removing it.
    @usableFromInline
    func _peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage._readElement(at: 0)
    }

    /// Returns the maximum element without removing it.
    @usableFromInline
    func _peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage._readElement(at: 0) }
        if count == 2 { return _storage._readElement(at: 1) }
        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        return Element.isLessThan(e1, e2) ? e2 : e1
    }

    /// Replaces the minimum and returns the old value.
    @usableFromInline
    mutating func _replaceMin(with replacement: Element) -> Element {
        let removed = _storage._readElement(at: 0)
        _storage._writeElement(at: 0, replacement)
        _trickleDownMin(Node.root)
        return removed
    }

    /// Replaces the maximum and returns the old value.
    @usableFromInline
    mutating func _replaceMax(with replacement: Element) -> Element {
        if count == 1 {
            let removed = _storage._readElement(at: 0)
            _storage._writeElement(at: 0, replacement)
            return removed
        }

        if count == 2 {
            let removed = _storage._readElement(at: 1)
            _storage._writeElement(at: 1, replacement)
            _bubbleUp(Node.leftMax)
            return removed
        }

        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        let maxIndex = Element.isLessThan(e1, e2) ? 2 : 1
        let removed = _storage._readElement(at: maxIndex)
        _storage._writeElement(at: maxIndex, replacement)
        let maxNode = Node(offset: maxIndex, level: 1)
        _bubbleUp(maxNode)
        _trickleDownMax(maxNode)
        return removed
    }

    /// A read-only view into the underlying storage.
    ///
    /// The elements are in heap order, which is **not** sorted order.
    /// Do not rely on any particular ordering - it may change between
    /// versions.
    ///
    /// - Complexity: O(n) to copy elements.
    @inlinable
    public var unordered: [Element] {
        var result: [Element] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(_storage._readElement(at: i))
        }
        return result
    }
}

// MARK: - Equatable (Copyable only)

extension Heap: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs._storage._readElement(at: i) != rhs._storage._readElement(at: i) {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (Copyable only)

extension Heap: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for i in 0..<count {
            hasher.combine(_storage._readElement(at: i))
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable only)

extension Heap: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
extension Heap: CustomStringConvertible {
    public var description: String {
        "Heap(\(count) elements)"
    }
}
#endif

// =============================================================================
// MARK: - Heap.Bounded Protocol Conformances (per MEM-COPY-006)
// =============================================================================
// Note: Sequence conformance is currently DISABLED due to a Swift compiler bug
// where protocol conformances for nested types break ~Copyable propagation
// even when in the same file as the type declaration.
// This appears to be triggered by the combination of `Element: ~Copyable & Protocol`
// constraint that Heap uses (vs Stack which only has `Element: ~Copyable`).
//
// As a workaround, use forEach() for iteration instead of for-in loops.
