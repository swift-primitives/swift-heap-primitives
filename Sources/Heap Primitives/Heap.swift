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

public import Index_Primitives
public import Comparison_Primitives

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

extension Heap {
    /// Typed error for Heap operations.
    ///
    /// Uses typed throws (`throws(Heap.Error)`) for compile-time exhaustiveness.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     let min = try heap.pop.min()
    /// } catch .empty {
    ///     print("Heap was empty")
    /// }
    /// ```
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty heap.
        case empty(Empty)
    }
}

// MARK: - Error Payloads

extension Heap.Error {
    /// Empty collection payload.
    public struct Empty: Sendable, Equatable {
        @inlinable
        public init() {}
    }
}

// MARK: - CustomStringConvertible

extension Heap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty: return "operation attempted on empty heap"
        }
    }
}

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (Heap.Bounded.Error, Heap.Inline.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - Heap<Element>.Bounded.Error
// - Heap<Element>.Inline.Error
// - Heap<Element>.Small.Error

/// Hoisted namespace for Heap variant error types.
///
/// This namespace enum avoids compound identifiers like `__HeapBoundedError`
/// per [API-NAME-002], providing the preferred `__Heap.Bounded.Error` pattern.
///
/// - Note: Use the typealias forms (e.g., ``Heap/Bounded/Error``) in your code,
///   not this namespace directly.
public enum __Heap {
    /// Namespace for Heap.Bounded error types.
    public enum Bounded {
        /// Errors that can occur during bounded heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Bounded/Error/invalidCapacity``: The requested capacity is invalid (negative).
        /// - ``__Heap/Bounded/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use ``Heap/Bounded/Push/Outcome`` to
        ///   preserve the element on overflow.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The requested capacity is invalid (negative).
            case invalidCapacity
            /// An operation was attempted on an empty heap.
            case empty
        }
    }

    /// Namespace for Heap.Inline error types.
    public enum Inline {
        /// Errors that can occur during inline heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Inline/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Overflow is NOT an error case. Per [API-ERR-005/006], push operations
        ///   that consume an element and can fail use ``Heap/Inline/Push/Outcome`` to
        ///   preserve the element on overflow.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }
    }

    /// Namespace for Heap.Small error types.
    public enum Small {
        /// Errors that can occur during small heap operations.
        ///
        /// ## Cases
        ///
        /// - ``__Heap/Small/Error/empty``: An operation was attempted on an empty heap.
        ///
        /// - Note: Small heaps grow to heap storage on overflow, so overflow is not possible.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }
    }
}

// MARK: - Hoisted Error CustomStringConvertible

extension __Heap.Bounded.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidCapacity:
            return "invalid capacity (negative)"
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Inline.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

extension __Heap.Small.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "operation attempted on empty heap"
        }
    }
}

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Heap where Element: ~Copyable {
    /// Internal node representation for min-max heap navigation.
    ///
    /// Tracks both the array offset and the tree level for efficient
    /// level-aware operations.
    @usableFromInline
    struct Node {
        @usableFromInline
        var offset: Int

        @usableFromInline
        var level: Int

        @inlinable
        init(offset: Int, level: Int) {
            self.offset = offset
            self.level = level
        }

        @inlinable
        init(offset: Int) {
            self.init(offset: offset, level: Self.level(forOffset: offset))
        }
    }
}

// Note: Comparable conformance moved to Heap.swift per MEM-COPY-006

// MARK: - Level Calculations

extension Heap.Node where Element: ~Copyable {
    /// Computes the level for a given offset.
    /// Level = floor(log2(offset + 1))
    @inlinable
    static func level(forOffset offset: Int) -> Int {
        (offset &+ 1)._binaryLogarithm()
    }

    /// Whether a level is a min level (even: 0, 2, 4, ...).
    @inlinable
    static func isMinLevel(_ level: Int) -> Bool {
        level & 0b1 == 0
    }

    /// Whether this node is on a min level.
    @inlinable
    var isMinLevel: Bool {
        Self.isMinLevel(level)
    }

    /// Whether this is the root node.
    @inlinable
    var isRoot: Bool {
        offset == 0
    }
}

// MARK: - Well-Known Nodes

extension Heap.Node where Element: ~Copyable {
    /// The root node (index 0, level 0).
    @inlinable
    static var root: Self {
        Self(offset: 0, level: 0)
    }

    /// The left child of root (index 1, level 1).
    @inlinable
    static var leftMax: Self {
        Self(offset: 1, level: 1)
    }

    /// The right child of root (index 2, level 1).
    @inlinable
    static var rightMax: Self {
        Self(offset: 2, level: 1)
    }

    /// First node on the given level.
    @inlinable
    static func firstNode(onLevel level: Int) -> Self {
        Self(offset: (1 &<< level) &- 1, level: level)
    }

    /// Last node on the given level.
    @inlinable
    static func lastNode(onLevel level: Int) -> Self {
        Self(offset: (1 &<< (level &+ 1)) &- 2, level: level)
    }
}

// MARK: - Navigation

extension Heap.Node where Element: ~Copyable {
    /// Returns the parent node.
    ///
    /// - Precondition: This is not the root.
    @inlinable
    func parent() -> Self {
        Self(offset: (offset &- 1) / 2, level: level &- 1)
    }

    /// Returns the grandparent node, if any.
    @inlinable
    func grandParent() -> Self? {
        guard offset > 2 else { return nil }
        return Self(offset: (offset &- 3) / 4, level: level &- 2)
    }

    /// Returns the left child node.
    @inlinable
    func leftChild() -> Self {
        Self(offset: offset &* 2 &+ 1, level: level &+ 1)
    }

    /// Returns the right child node.
    @inlinable
    func rightChild() -> Self {
        Self(offset: offset &* 2 &+ 2, level: level &+ 1)
    }

    /// Returns the first grandchild node.
    @inlinable
    func firstGrandchild() -> Self {
        Self(offset: offset &* 4 &+ 3, level: level &+ 2)
    }

    /// Returns the last grandchild node.
    @inlinable
    func lastGrandchild() -> Self {
        Self(offset: offset &* 4 &+ 6, level: level &+ 2)
    }
}

// MARK: - Range Operations

extension Heap.Node where Element: ~Copyable {
    /// Returns the range of nodes on a level up to a limit.
    @inlinable
    static func allNodes(onLevel level: Int, limit: Int) -> ClosedRange<Self>? {
        let first = Self.firstNode(onLevel: level)
        guard first.offset < limit else { return nil }
        var last = Self.lastNode(onLevel: level)
        if last.offset >= limit {
            last.offset = limit &- 1
        }
        return first ... last
    }
}

// MARK: - Binary Logarithm

extension Int {
    /// Computes floor(log2(self)).
    ///
    /// - Precondition: self > 0
    @usableFromInline
    func _binaryLogarithm() -> Int {
        precondition(self > 0)
        return Int.bitWidth - 1 - self.leadingZeroBitCount
    }
}

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
/// ## Iteration
///
/// Due to a Swift compiler bug, `Sequence` conformance is disabled for `Heap`
/// and its variants. Use `forEach(_:)` for iteration instead of `for-in` loops:
///
/// ```swift
/// // Instead of: for element in heap { ... }
/// heap.forEach { element in
///     print(element)
/// }
/// ```
///
/// Elements are yielded in heap order (not sorted order). For sorted iteration,
/// repeatedly call `takeMin()` or `takeMax()`.
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
public struct Heap<Element: ~Copyable & Comparison_Primitives.Comparison.`Protocol`>: ~Copyable {

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
            unsafe self._heapPtr = nil
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
    /// This is a typealias to `Comparison.Protocol` from comparison-primitives,
    /// which provides borrowing-based comparison for `~Copyable` types.
    ///
    /// ## Usage
    ///
    /// For `~Copyable` types, implement the `<` and `==` operators:
    /// ```swift
    /// struct UniqueResource: ~Copyable, Heap.Ordering {
    ///     let priority: Int
    ///
    ///     static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    ///         lhs.priority < rhs.priority
    ///     }
    ///
    ///     static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    ///         lhs.priority == rhs.priority
    ///     }
    /// }
    /// ```
    ///
    /// Standard library types (`Int`, `String`, etc.) already conform to
    /// `Comparison.Protocol` and work automatically with heaps.
    public typealias Ordering = Comparison_Primitives.Comparison.`Protocol`
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

        // Find max (at index 1 or 2) using < operator
        let ptr = unsafe _cachedPtr
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1

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
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1
        return body(unsafe ptr[maxIndex])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// This method is the primary iteration mechanism for `Heap` because
    /// `Sequence` conformance is disabled due to a Swift compiler bug. Use this
    /// instead of `for-in` loops:
    ///
    /// ```swift
    /// // Instead of: for element in heap { ... }
    /// heap.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
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

        // Compare using Comparison.Protocol with borrowing
        let nodeIsLess = unsafe ptr[node.offset] < ptr[parent.offset]
        let parentIsLess = unsafe ptr[parent.offset] < ptr[node.offset]

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            _swapElements(at: node.offset, parent.offset)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = unsafe ptr[grandparent.offset] < ptr[node.offset]
                guard !gpIsLess else { break }  // node < grandparent
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = unsafe ptr[node.offset] < ptr[grandparent.offset]
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

            if unsafe ptr[leftChild.offset] < ptr[smallestOffset] {
                smallest = leftChild
                smallestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[rightChild.offset] < ptr[smallestOffset] {
                    smallest = rightChild
                    smallestOffset = rightChild.offset
                }
            }

            // Check grandchildren
            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[gcOffset] < ptr[smallestOffset] {
                    smallest = Node(offset: gcOffset, level: gc0.level)
                    smallestOffset = gcOffset
                }
            }

            if smallest.offset == node.offset { break }

            _swapElements(at: node.offset, smallest.offset)

            // If swapped with grandchild, may need to swap with parent
            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if unsafe ptr[parent.offset] < ptr[smallest.offset] {
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
            if unsafe ptr[largestOffset] < ptr[leftChild.offset] {
                largest = leftChild
                largestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[largestOffset] < ptr[rightChild.offset] {
                    largest = rightChild
                    largestOffset = rightChild.offset
                }
            }

            // Check grandchildren
            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[largestOffset] < ptr[gcOffset] {
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
                if unsafe ptr[largest.offset] < ptr[parent.offset] {
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
    public init(_ elements: some Swift.Sequence<Element>) {
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
        return e1 < e2 ? e2 : e1
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
        let maxIndex = e1 < e2 ? 2 : 1
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
//
// SWIFT COMPILER BUG: Swift.Sequence Conformance Disabled
// ==================================================
//
// The `Sequence` conformance for `Heap.Bounded` is DISABLED due to a Swift
// compiler bug that causes `~Copyable` constraint propagation to fail during
// module emission (`-emit-module` flag).
//
// ## Bug Conditions
//
// The bug manifests when ALL of the following conditions are met:
//
// 1. Generic type has compound constraint: `Element: ~Copyable & Protocol`
// 2. Nested type contains `UnsafeMutablePointer<Element>` stored property
// 3. Conditional protocol conformance exists (e.g., `Sequence where Element: Copyable`)
// 4. Compiled with `-emit-module` flag (used by Swift Package Manager)
// 5. Compiled with `-enable-experimental-feature Lifetimes`
//
// ## Error Manifestation
//
// The error appears on the `_cachedPtr` stored property declaration:
//
//     error: type 'Element' does not conform to protocol 'Copyable'
//     var _cachedPtr: UnsafeMutablePointer<Element>
//
// ## Why Stack Works But Heap Doesn't
//
// `Stack<Element: ~Copyable>` compiles successfully with Sequence conformance
// because it has a SINGLE constraint. The compound constraint in
// `Heap<Element: ~Copyable & Comparison.`Protocol`>` triggers different behavior in
// the compiler's constraint solver during module interface generation.
//
// ## Compilation Mode Behavior
//
// - `swiftc -parse *.swift` → SUCCESS (no module emission)
// - `swiftc -emit-module *.swift` → FAILURE (module emission triggers bug)
//
// ## Workaround
//
// Use `forEach(_:)` for iteration instead of `for-in` loops:
//
//     // Instead of: for element in heap { ... }
//     heap.forEach { element in ... }
//
// ## Tracking
//
// This represents a Category 4 failure mode beyond MEM-COPY-006.
// The bug is specific to the interaction between:
// - Compound generic constraints with `~Copyable`
// - Module emission phase type checking
// - Conditional protocol conformances
//
// Tracked: https://github.com/swiftlang/swift/issues/86669
//
// WORKAROUND: This Sequence conformance only compiles because all source code
// is consolidated into a single file. When the compiler bug is fixed, this
// package can be restructured into multiple files per [API-IMPL-005].
//
// =============================================================================

extension Heap.Bounded: Swift.Sequence where Element: Copyable {

    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: Heap<Element>.Storage

        @usableFromInline
        var _index: Int = 0

        @usableFromInline
        init(_storage: Heap<Element>.Storage) {
            self._storage = _storage
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _storage.header else { return nil }
            defer { _index += 1 }
            return _storage._readElement(at: _index)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage: _storage)
    }
}

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

// Note: Heap.Bounded is declared INSIDE the Heap struct body (in Heap.swift)
// due to a Swift compiler bug where nested types declared in extensions do not
// properly inherit ~Copyable constraints from the outer type.
// This file contains only extensions to Heap.Bounded.

// MARK: - Properties

extension Heap.Bounded where Element: ~Copyable {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _storage.header }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _storage.header == capacity }
}

// Note: Push.Outcome is declared in Heap.swift struct body per MEM-COPY-006

// MARK: - Internal Heap Operations

extension Heap.Bounded where Element: ~Copyable {
    /// Inserts an element and restores heap property.
    @usableFromInline
    mutating func _insert(_ element: consuming Element) {
        let index = _storage.header
        _storage._initializeElement(at: index, to: element)
        _storage.header += 1
        _bubbleUp(Heap.Node(offset: index))
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
        _trickleDownMin(Heap.Node.root)
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

        // Find max (at index 1 or 2) using < operator
        let ptr = unsafe _cachedPtr
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1

        // Swap with last, remove last, trickle down
        let lastIndex = _storage.header - 1
        _swapElements(at: maxIndex, lastIndex)
        _storage.header -= 1
        let removed = _storage._moveElement(at: lastIndex)

        if maxIndex < _storage.header {
            _trickleDownMax(Heap.Node(offset: maxIndex, level: 1))
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

// MARK: - Bubble Up

extension Heap.Bounded where Element: ~Copyable {
    /// Restores heap property by moving element up.
    @usableFromInline
    mutating func _bubbleUp(_ node: Heap<Element>.Node) {
        guard !node.isRoot else { return }

        let parent = node.parent()
        var node = node

        let ptr = unsafe _cachedPtr

        let nodeIsLess = unsafe ptr[node.offset] < ptr[parent.offset]
        let parentIsLess = unsafe ptr[parent.offset] < ptr[node.offset]

        if (node.isMinLevel && parentIsLess)
            || (!node.isMinLevel && nodeIsLess) {
            _swapElements(at: node.offset, parent.offset)
            node = parent
        }

        if node.isMinLevel {
            while let grandparent = node.grandParent() {
                let gpIsLess = unsafe ptr[grandparent.offset] < ptr[node.offset]
                guard !gpIsLess else { break }
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        } else {
            while let grandparent = node.grandParent() {
                let nodeIsLessGp = unsafe ptr[node.offset] < ptr[grandparent.offset]
                guard !nodeIsLessGp else { break }
                _swapElements(at: node.offset, grandparent.offset)
                node = grandparent
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Bounded where Element: ~Copyable {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMin(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var smallest = node
            var smallestOffset = node.offset

            let rightChild = node.rightChild()

            if unsafe ptr[leftChild.offset] < ptr[smallestOffset] {
                smallest = leftChild
                smallestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[rightChild.offset] < ptr[smallestOffset] {
                    smallest = rightChild
                    smallestOffset = rightChild.offset
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[gcOffset] < ptr[smallestOffset] {
                    smallest = Heap.Node(offset: gcOffset, level: gc0.level)
                    smallestOffset = gcOffset
                }
            }

            if smallest.offset == node.offset { break }

            _swapElements(at: node.offset, smallest.offset)

            if smallest.offset >= gc0.offset {
                let parent = smallest.parent()
                if unsafe ptr[parent.offset] < ptr[smallest.offset] {
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

extension Heap.Bounded where Element: ~Copyable {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMax(_ startNode: Heap<Element>.Node) {
        var node = startNode
        let count = _storage.header
        let ptr = unsafe _cachedPtr

        while true {
            let leftChild = node.leftChild()
            if leftChild.offset >= count { break }

            var largest = node
            var largestOffset = node.offset

            let rightChild = node.rightChild()

            if unsafe ptr[largestOffset] < ptr[leftChild.offset] {
                largest = leftChild
                largestOffset = leftChild.offset
            }
            if rightChild.offset < count {
                if unsafe ptr[largestOffset] < ptr[rightChild.offset] {
                    largest = rightChild
                    largestOffset = rightChild.offset
                }
            }

            let gc0 = node.firstGrandchild()
            for i in 0..<4 {
                let gcOffset = gc0.offset + i
                guard gcOffset < count else { break }
                if unsafe ptr[largestOffset] < ptr[gcOffset] {
                    largest = Heap.Node(offset: gcOffset, level: gc0.level)
                    largestOffset = gcOffset
                }
            }

            if largest.offset == node.offset { break }

            _swapElements(at: node.offset, largest.offset)

            if largest.offset >= gc0.offset {
                let parent = largest.parent()
                if unsafe ptr[largest.offset] < ptr[parent.offset] {
                    _swapElements(at: largest.offset, parent.offset)
                }
                node = largest
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Bounded where Element: ~Copyable {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    mutating func _heapify() {
        let count = _storage.header
        guard count > 1 else { return }

        let limit = count / 2

        var level = Heap.Node.level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = Heap.Node.firstNode(onLevel: level)
            let lastOnLevel = Heap.Node.lastNode(onLevel: level)

            let startOffset = firstOnLevel.offset
            let endOffset = Swift.min(lastOnLevel.offset, limit - 1)

            if Heap.Node.isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(Heap.Node(offset: offset, level: level))
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(Heap.Node(offset: offset, level: level))
                }
            }
            level -= 1
        }
    }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Heap.Bounded where Element: ~Copyable {
    /// Pushes an element onto the heap.
    ///
    /// Returns an ``Outcome`` indicating whether the element was inserted
    /// or returned due to overflow.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: consuming Element) -> Push.Outcome {
        guard _storage.header < capacity else {
            return .overflow(element)
        }
        _insert(element)
        return .inserted
    }

    /// Takes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMin() -> Element? {
        _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMax() -> Element? {
        _removeMax()
    }

    /// Pops and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Heap/Bounded/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMin() throws(__Heap.Bounded.Error) -> Element {
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/Bounded/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMax() throws(__Heap.Bounded.Error) -> Element {
        guard let element = _removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// The capacity remains unchanged.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        let count = _storage.header
        if count > 0 {
            _storage._deinitializeElements(in: 0..<count)
        }
        _storage.header = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Bounded where Element: ~Copyable {
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
        let maxIndex = unsafe ptr[1] < ptr[2] ? 2 : 1
        return body(unsafe ptr[maxIndex])
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// This method is the primary iteration mechanism for `Heap.Bounded` because
    /// `Sequence` conformance is disabled due to a Swift compiler bug. Use this
    /// instead of `for-in` loops:
    ///
    /// ```swift
    /// // Instead of: for element in heap { ... }
    /// heap.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
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

// MARK: - Copy-on-Write (Copyable elements only)

extension Heap.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = Heap.Storage.create(minimumCapacity: capacity)
            let currentCount = _storage.header
            _storage._copyAllElements(to: newStorage, count: currentCount)
            newStorage.header = currentCount
            _storage = newStorage
            unsafe (_cachedPtr = _storage._elementsPointer)
        }
    }

    /// Pushes an element onto the heap (CoW-aware).
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: Element) -> Push.Outcome {
        _makeUnique()
        guard _storage.header < capacity else {
            return .overflow(element)
        }
        _insert(element)
        return .inserted
    }

    /// Takes and returns the minimum element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func takeMin() -> Element? {
        _makeUnique()
        return _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty (CoW-aware).
    @inlinable
    public mutating func takeMax() -> Element? {
        _makeUnique()
        return _removeMax()
    }

    /// Pops and returns the minimum element (CoW-aware).
    @inlinable
    public mutating func popMin() throws(__Heap.Bounded.Error) -> Element {
        _makeUnique()
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element (CoW-aware).
    @inlinable
    public mutating func popMax() throws(__Heap.Bounded.Error) -> Element {
        _makeUnique()
        guard let element = _removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap (CoW-aware).
    @inlinable
    public mutating func clear() {
        _makeUnique()
        let count = _storage.header
        if count > 0 {
            _storage._deinitializeElements(in: 0..<count)
        }
        _storage.header = 0
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Bounded where Element: Copyable {
    /// Returns the minimum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return _storage._readElement(at: 0)
    }

    /// Returns the maximum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return _storage._readElement(at: 0) }
        if count == 2 { return _storage._readElement(at: 1) }
        let e1 = _storage._readElement(at: 1)
        let e2 = _storage._readElement(at: 2)
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.Bounded where Element: Copyable {
    /// Creates a bounded heap from a sequence.
    ///
    /// - Parameters:
    ///   - elements: The sequence of elements.
    ///   - capacity: Maximum number of elements. Must be non-negative.
    /// - Throws: ``Heap/Bounded/Error/invalidCapacity`` if capacity is negative.
    /// - Note: If elements exceeds capacity, only the first `capacity` elements are kept.
    /// - Complexity: O(n)
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>, capacity: Int) throws(__Heap.Bounded.Error) {
        guard capacity >= 0 else {
            throw .invalidCapacity
        }

        self._storage = Heap.Storage.create(minimumCapacity: capacity)
        unsafe (self._cachedPtr = _storage._elementsPointer)
        self.capacity = capacity

        for element in elements {
            if _storage.header >= capacity { break }
            _storage._initializeElement(at: _storage.header, to: element)
            _storage.header += 1
        }

        if _storage.header > 1 {
            _heapify()
        }
    }
}

// Note: Swift.Sequence, Equatable, Hashable conformances moved to Heap.swift per MEM-COPY-006

// MARK: - Truncate

extension Heap.Bounded where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    /// This is a truncation, not maintaining heap property for the removed elements.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        let currentCount = _storage.header
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        _storage._deinitializeElements(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

extension Heap.Bounded where Element: Copyable {
    /// Removes elements beyond the specified count (CoW-aware).
    @inlinable
    public mutating func truncate(to newCount: Int) {
        _makeUnique()
        let currentCount = _storage.header
        guard newCount < currentCount else { return }
        let targetCount = Swift.max(0, newCount)

        _storage._deinitializeElements(in: targetCount..<currentCount)
        _storage.header = targetCount
    }
}

// MARK: - Span Access

extension Heap.Bounded where Element: ~Copyable {
    /// A read-only view of the heap's elements in heap order.
    ///
    /// Elements are in heap order, which is **not** sorted order.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            unsafe Span(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }

    /// A mutable view of the heap's elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    ///   After modification, you may need to re-heapify.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

extension Heap.Bounded where Element: Copyable {
    /// A mutable view of the heap's elements (CoW-aware).
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            _makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _storage.header)
        }
    }
}

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

// Note: Heap.Inline is declared INSIDE the Heap struct body (in Heap.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Heap.Inline.

// MARK: - Properties

extension Heap.Inline where Element: ~Copyable {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the heap is full.
    @inlinable
    public var isFull: Bool { _count == capacity }
}

// Note: Push.Outcome is declared in Heap.swift struct body per MEM-COPY-006

// MARK: - Internal Heap Operations

extension Heap.Inline where Element: ~Copyable {
    /// Inserts an element and restores heap property.
    @usableFromInline
    mutating func _insert(_ element: consuming Element) {
        let index = _count
        unsafe _pointerToElement(at: index).initialize(to: element)
        _count += 1
        _bubbleUp(index)
    }

    /// Removes and returns the minimum element.
    @usableFromInline
    mutating func _removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            return unsafe _pointerToElement(at: 0).move()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: 0, lastIndex)
        _count -= 1
        let removed = unsafe _pointerToElement(at: lastIndex).move()
        _trickleDownMin(0)
        return removed
    }

    /// Removes and returns the maximum element.
    @usableFromInline
    mutating func _removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            return unsafe _pointerToElement(at: 0).move()
        }

        if count == 2 {
            _count = 1
            return unsafe _pointerToElement(at: 1).move()
        }

        // Find max (at index 1 or 2) using < operator
        let maxIndex: Int
        if unsafe _readPointerToElement(at: 1).pointee < _readPointerToElement(at: 2).pointee {
            maxIndex = 2
        } else {
            maxIndex = 1
        }

        // Swap with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: maxIndex, lastIndex)
        _count -= 1
        let removed = unsafe _pointerToElement(at: lastIndex).move()

        if maxIndex < _count {
            _trickleDownMax(maxIndex, level: 1)
        }

        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    mutating func _swapElements(at i: Int, _ j: Int) {
        let ptrI = unsafe _pointerToElement(at: i)
        let ptrJ = unsafe _pointerToElement(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Level Calculations

extension Heap.Inline where Element: ~Copyable {
    /// Computes the level for a given offset.
    @usableFromInline
    static func _level(forOffset offset: Int) -> Int {
        (offset &+ 1)._binaryLogarithm()
    }

    /// Whether a level is a min level (even: 0, 2, 4, ...).
    @usableFromInline
    static func _isMinLevel(_ level: Int) -> Bool {
        level & 0b1 == 0
    }
}

// MARK: - Bubble Up

extension Heap.Inline where Element: ~Copyable {
    /// Restores heap property by moving element up.
    @usableFromInline
    mutating func _bubbleUp(_ nodeOffset: Int) {
        guard nodeOffset > 0 else { return }

        let parentOffset = (nodeOffset &- 1) / 2
        var nodeOffset = nodeOffset
        var level = Self._level(forOffset: nodeOffset)

        let nodeIsLess = unsafe _readPointerToElement(at: nodeOffset).pointee < _readPointerToElement(at: parentOffset).pointee
        let parentIsLess = unsafe _readPointerToElement(at: parentOffset).pointee < _readPointerToElement(at: nodeOffset).pointee

        let isMinLevel = Self._isMinLevel(level)

        if (isMinLevel && parentIsLess) || (!isMinLevel && nodeIsLess) {
            _swapElements(at: nodeOffset, parentOffset)
            nodeOffset = parentOffset
            level -= 1
        }

        if Self._isMinLevel(level) {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let gpIsLess = unsafe _readPointerToElement(at: gpOffset).pointee < _readPointerToElement(at: nodeOffset).pointee
                guard !gpIsLess else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        } else {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let nodeIsLessGp = unsafe _readPointerToElement(at: nodeOffset).pointee < _readPointerToElement(at: gpOffset).pointee
                guard !nodeIsLessGp else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Inline where Element: ~Copyable {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMin(_ startOffset: Int) {
        var nodeOffset = startOffset
        var level = Self._level(forOffset: startOffset)

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var smallestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if unsafe _readPointerToElement(at: leftChildOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                smallestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if unsafe _readPointerToElement(at: rightChildOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    smallestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if unsafe _readPointerToElement(at: gcOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    smallestOffset = gcOffset
                }
            }

            if smallestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, smallestOffset)

            if smallestOffset >= gc0 {
                let parentOffset = (smallestOffset &- 1) / 2
                if unsafe _readPointerToElement(at: parentOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    _swapElements(at: smallestOffset, parentOffset)
                }
                nodeOffset = smallestOffset
                level += 2
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.Inline where Element: ~Copyable {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMax(_ startOffset: Int, level startLevel: Int) {
        var nodeOffset = startOffset
        var level = startLevel

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var largestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: leftChildOffset).pointee {
                largestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: rightChildOffset).pointee {
                    largestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: gcOffset).pointee {
                    largestOffset = gcOffset
                }
            }

            if largestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, largestOffset)

            if largestOffset >= gc0 {
                let parentOffset = (largestOffset &- 1) / 2
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: parentOffset).pointee {
                    _swapElements(at: largestOffset, parentOffset)
                }
                nodeOffset = largestOffset
                level += 2
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Inline where Element: ~Copyable {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    mutating func _heapify() {
        guard _count > 1 else { return }

        let limit = _count / 2

        var level = Self._level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = (1 &<< level) &- 1
            let lastOnLevel = (1 &<< (level &+ 1)) &- 2

            let startOffset = firstOnLevel
            let endOffset = Swift.min(lastOnLevel, limit - 1)

            if Self._isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(offset)
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(offset, level: level)
                }
            }
            level -= 1
        }
    }
}

// MARK: - Core Operations

extension Heap.Inline where Element: ~Copyable {
    /// Pushes an element onto the heap.
    ///
    /// Returns an ``Outcome`` indicating whether the element was inserted
    /// or returned due to overflow.
    ///
    /// - Parameter element: The element to push.
    /// - Returns: `.inserted` if successful, `.overflow(element)` if the heap is full.
    /// - Complexity: O(log n)
    @inlinable
    @discardableResult
    public mutating func push(_ element: consuming Element) -> Push.Outcome {
        guard _count < capacity else {
            return .overflow(element)
        }
        _insert(element)
        return .inserted
    }

    /// Takes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMin() -> Element? {
        _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMax() -> Element? {
        _removeMax()
    }

    /// Pops and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Heap/Inline/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMin() throws(__Heap.Inline.Error) -> Element {
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/Inline/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMax() throws(__Heap.Inline.Error) -> Element {
        guard let element = _removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Inline where Element: ~Copyable {
    /// Provides borrowing access to the minimum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the minimum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return unsafe body(_readPointerToElement(at: 0).pointee)
    }

    /// Provides borrowing access to the maximum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the maximum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return unsafe body(_readPointerToElement(at: 0).pointee) }
        if count == 2 { return unsafe body(_readPointerToElement(at: 1).pointee) }

        let e1IsLess = unsafe _readPointerToElement(at: 1).pointee < _readPointerToElement(at: 2).pointee
        let maxIndex = e1IsLess ? 2 : 1
        return unsafe body(_readPointerToElement(at: maxIndex).pointee)
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// This method is the primary iteration mechanism for `Heap.Inline` because
    /// `Sequence` conformance is disabled due to a Swift compiler bug. Use this
    /// instead of `for-in` loops:
    ///
    /// ```swift
    /// // Instead of: for element in heap { ... }
    /// heap.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<count {
            body(unsafe _readPointerToElement(at: i).pointee)
        }
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Inline where Element: Copyable {
    /// Returns the minimum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return unsafe _readPointerToElement(at: 0).pointee
    }

    /// Returns the maximum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return unsafe _readPointerToElement(at: 0).pointee }
        if count == 2 { return unsafe _readPointerToElement(at: 1).pointee }

        let e1 = unsafe _readPointerToElement(at: 1).pointee
        let e2 = unsafe _readPointerToElement(at: 2).pointee
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Truncate

extension Heap.Inline where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        guard newCount < _count else { return }
        let targetCount = Swift.max(0, newCount)

        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_storage) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in targetCount..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = targetCount
    }
}

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

// Note: Heap.Small is declared INSIDE the Heap struct body (in Heap.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Heap.Small.

// MARK: - Properties

extension Heap.Small where Element: ~Copyable {
    /// The current number of elements in the heap.
    @inlinable
    public var count: Int { _count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity (inline or heap).
    @inlinable
    public var capacity: Int {
        if let heap = _heap {
            return heap.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Internal Heap Operations

extension Heap.Small where Element: ~Copyable {
    /// Returns a pointer to the element at the given index.
    @usableFromInline
    @unsafe
    mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        if let heapPtr = unsafe _heapPtr {
            return unsafe heapPtr + index
        } else {
            return unsafe _inlinePointerToElement(at: index)
        }
    }

    /// Returns a read pointer to the element at the given index.
    @usableFromInline
    @unsafe
    func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
        if let heapPtr = unsafe _heapPtr {
            return unsafe UnsafePointer(heapPtr + index)
        } else {
            return unsafe _inlineReadPointerToElement(at: index)
        }
    }

    /// Inserts an element and restores heap property.
    @usableFromInline
    mutating func _insert(_ element: consuming Element) {
        let index = _count
        unsafe _pointerToElement(at: index).initialize(to: element)
        _count += 1
        if _heap != nil {
            _heap!.header = _count
        }
        _bubbleUp(index)
    }

    /// Removes and returns the minimum element.
    @usableFromInline
    mutating func _removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            if _heap != nil {
                _heap!.header = 0
            }
            return unsafe _pointerToElement(at: 0).move()
        }

        // Swap root with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: 0, lastIndex)
        _count -= 1
        if _heap != nil {
            _heap!.header = _count
        }
        let removed = unsafe _pointerToElement(at: lastIndex).move()
        _trickleDownMin(0)
        return removed
    }

    /// Removes and returns the maximum element.
    @usableFromInline
    mutating func _removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if count == 1 {
            _count = 0
            if _heap != nil {
                _heap!.header = 0
            }
            return unsafe _pointerToElement(at: 0).move()
        }

        if count == 2 {
            _count = 1
            if _heap != nil {
                _heap!.header = 1
            }
            return unsafe _pointerToElement(at: 1).move()
        }

        // Find max (at index 1 or 2) using < operator
        let maxIndex: Int
        if unsafe _readPointerToElement(at: 1).pointee < _readPointerToElement(at: 2).pointee {
            maxIndex = 2
        } else {
            maxIndex = 1
        }

        // Swap with last, remove last, trickle down
        let lastIndex = _count - 1
        _swapElements(at: maxIndex, lastIndex)
        _count -= 1
        if _heap != nil {
            _heap!.header = _count
        }
        let removed = unsafe _pointerToElement(at: lastIndex).move()

        if maxIndex < _count {
            _trickleDownMax(maxIndex, level: 1)
        }

        return removed
    }

    /// Swaps elements at two indices.
    @usableFromInline
    mutating func _swapElements(at i: Int, _ j: Int) {
        let ptrI = unsafe _pointerToElement(at: i)
        let ptrJ = unsafe _pointerToElement(at: j)
        let temp = unsafe ptrI.move()
        unsafe ptrI.initialize(to: ptrJ.move())
        unsafe ptrJ.initialize(to: temp)
    }
}

// MARK: - Level Calculations

extension Heap.Small where Element: ~Copyable {
    /// Computes the level for a given offset.
    @usableFromInline
    static func _level(forOffset offset: Int) -> Int {
        (offset &+ 1)._binaryLogarithm()
    }

    /// Whether a level is a min level (even: 0, 2, 4, ...).
    @usableFromInline
    static func _isMinLevel(_ level: Int) -> Bool {
        level & 0b1 == 0
    }
}

// MARK: - Bubble Up

extension Heap.Small where Element: ~Copyable {
    /// Restores heap property by moving element up.
    @usableFromInline
    mutating func _bubbleUp(_ nodeOffset: Int) {
        guard nodeOffset > 0 else { return }

        let parentOffset = (nodeOffset &- 1) / 2
        var nodeOffset = nodeOffset
        var level = Self._level(forOffset: nodeOffset)

        let nodeIsLess = unsafe _readPointerToElement(at: nodeOffset).pointee < _readPointerToElement(at: parentOffset).pointee
        let parentIsLess = unsafe _readPointerToElement(at: parentOffset).pointee < _readPointerToElement(at: nodeOffset).pointee

        let isMinLevel = Self._isMinLevel(level)

        if (isMinLevel && parentIsLess) || (!isMinLevel && nodeIsLess) {
            _swapElements(at: nodeOffset, parentOffset)
            nodeOffset = parentOffset
            level -= 1
        }

        if Self._isMinLevel(level) {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let gpIsLess = unsafe _readPointerToElement(at: gpOffset).pointee < _readPointerToElement(at: nodeOffset).pointee
                guard !gpIsLess else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        } else {
            while nodeOffset > 2 {
                let gpOffset = (nodeOffset &- 3) / 4
                let nodeIsLessGp = unsafe _readPointerToElement(at: nodeOffset).pointee < _readPointerToElement(at: gpOffset).pointee
                guard !nodeIsLessGp else { break }
                _swapElements(at: nodeOffset, gpOffset)
                nodeOffset = gpOffset
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.Small where Element: ~Copyable {
    /// Sinks element at min-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMin(_ startOffset: Int) {
        var nodeOffset = startOffset

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var smallestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if unsafe _readPointerToElement(at: leftChildOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                smallestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if unsafe _readPointerToElement(at: rightChildOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    smallestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if unsafe _readPointerToElement(at: gcOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    smallestOffset = gcOffset
                }
            }

            if smallestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, smallestOffset)

            if smallestOffset >= gc0 {
                let parentOffset = (smallestOffset &- 1) / 2
                if unsafe _readPointerToElement(at: parentOffset).pointee < _readPointerToElement(at: smallestOffset).pointee {
                    _swapElements(at: smallestOffset, parentOffset)
                }
                nodeOffset = smallestOffset
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.Small where Element: ~Copyable {
    /// Sinks element at max-level node to correct position.
    @usableFromInline
    mutating func _trickleDownMax(_ startOffset: Int, level startLevel: Int) {
        var nodeOffset = startOffset

        while true {
            let leftChildOffset = nodeOffset &* 2 &+ 1
            if leftChildOffset >= _count { break }

            var largestOffset = nodeOffset

            let rightChildOffset = nodeOffset &* 2 &+ 2

            if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: leftChildOffset).pointee {
                largestOffset = leftChildOffset
            }
            if rightChildOffset < _count {
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: rightChildOffset).pointee {
                    largestOffset = rightChildOffset
                }
            }

            let gc0 = nodeOffset &* 4 &+ 3
            for i in 0..<4 {
                let gcOffset = gc0 + i
                guard gcOffset < _count else { break }
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: gcOffset).pointee {
                    largestOffset = gcOffset
                }
            }

            if largestOffset == nodeOffset { break }

            _swapElements(at: nodeOffset, largestOffset)

            if largestOffset >= gc0 {
                let parentOffset = (largestOffset &- 1) / 2
                if unsafe _readPointerToElement(at: largestOffset).pointee < _readPointerToElement(at: parentOffset).pointee {
                    _swapElements(at: largestOffset, parentOffset)
                }
                nodeOffset = largestOffset
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify

extension Heap.Small where Element: ~Copyable {
    /// Converts storage to valid min-max heap in O(n).
    @usableFromInline
    mutating func _heapify() {
        guard _count > 1 else { return }

        let limit = _count / 2

        var level = Self._level(forOffset: limit - 1)
        while level >= 0 {
            let firstOnLevel = (1 &<< level) &- 1
            let lastOnLevel = (1 &<< (level &+ 1)) &- 2

            let startOffset = firstOnLevel
            let endOffset = Swift.min(lastOnLevel, limit - 1)

            if Self._isMinLevel(level) {
                for offset in startOffset...endOffset {
                    _trickleDownMin(offset)
                }
            } else {
                for offset in startOffset...endOffset {
                    _trickleDownMax(offset, level: level)
                }
            }
            level -= 1
        }
    }
}

// MARK: - Heap Growth

extension Heap.Small where Element: ~Copyable {
    /// Internal: push element to heap storage.
    @usableFromInline
    mutating func _pushToHeap(_ element: consuming Element) {
        guard let heap = _heap, let _ = unsafe _heapPtr else {
            preconditionFailure("_pushToHeap called without heap storage")
        }

        // Check if we need to grow
        if _count >= heap.capacity {
            _growHeap(minimumCapacity: _count + 1)
        }

        unsafe (_heapPtr! + _count).initialize(to: element)
        _count += 1
        heap.header = _count
        _bubbleUp(_count - 1)
    }

    /// Internal: grow heap storage.
    @usableFromInline
    mutating func _growHeap(minimumCapacity: Int) {
        guard let oldStorage = _heap else {
            preconditionFailure("_growHeap called without heap storage")
        }

        let newCapacity = Swift.max(minimumCapacity, oldStorage.capacity * 2)
        let newStorage = Heap<Element>.Storage.create(minimumCapacity: newCapacity)

        oldStorage._moveAllElements(to: newStorage, count: _count)
        newStorage.header = _count
        oldStorage.header = 0  // Elements moved, prevent double-free

        _heap = newStorage
        unsafe (_heapPtr = newStorage._elementsPointer)
    }
}

// MARK: - Core Operations

extension Heap.Small where Element: ~Copyable {
    /// Pushes an element onto the heap.
    ///
    /// If the heap exceeds inline capacity, elements are moved to heap storage.
    /// Push operations never fail - the heap grows automatically.
    ///
    /// - Parameter element: The element to push.
    /// - Complexity: O(log n) amortized, O(n) when spilling to heap.
    @inlinable
    public mutating func push(_ element: consuming Element) {
        if _heap != nil {
            // Already spilled - push to heap
            _pushToHeap(element)
        } else if _count < inlineCapacity {
            // Still inline and have space
            _insert(element)
        } else {
            // Need to spill
            _spillToHeap(minimumCapacity: _count + 1)
            _pushToHeap(element)
        }
    }

    /// Takes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMin() -> Element? {
        _removeMin()
    }

    /// Takes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func takeMax() -> Element? {
        _removeMax()
    }

    /// Pops and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Heap/Small/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMin() throws(__Heap.Small.Error) -> Element {
        guard let element = _removeMin() else {
            throw .empty
        }
        return element
    }

    /// Pops and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/Small/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func popMax() throws(__Heap.Small.Error) -> Element {
        guard let element = _removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the heap.
    ///
    /// Does not shrink back to inline storage if spilled.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        guard _count > 0 else { return }

        if let heap = _heap {
            heap._deinitializeElements(in: 0..<_count)
            heap.header = 0
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in 0..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = 0
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.Small where Element: ~Copyable {
    /// Provides borrowing access to the minimum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the minimum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        return unsafe body(_readPointerToElement(at: 0).pointee)
    }

    /// Provides borrowing access to the maximum element.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the maximum.
    /// - Returns: The value returned by the closure, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard count > 0 else { return nil }
        if count == 1 { return unsafe body(_readPointerToElement(at: 0).pointee) }
        if count == 2 { return unsafe body(_readPointerToElement(at: 1).pointee) }

        let e1IsLess = unsafe _readPointerToElement(at: 1).pointee < _readPointerToElement(at: 2).pointee
        let maxIndex = e1IsLess ? 2 : 1
        return unsafe body(_readPointerToElement(at: maxIndex).pointee)
    }

    /// Calls the given closure for each element in heap order.
    ///
    /// This method is the primary iteration mechanism for `Heap.Small` because
    /// `Sequence` conformance is disabled due to a Swift compiler bug. Use this
    /// instead of `for-in` loops:
    ///
    /// ```swift
    /// // Instead of: for element in heap { ... }
    /// heap.forEach { element in
    ///     print(element)
    /// }
    /// ```
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///   For sorted iteration, repeatedly call `takeMin()` or `takeMax()`.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<count {
            body(unsafe _readPointerToElement(at: i).pointee)
        }
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Small where Element: Copyable {
    /// Returns the minimum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMin() -> Element? {
        guard !isEmpty else { return nil }
        return unsafe _readPointerToElement(at: 0).pointee
    }

    /// Returns the maximum element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekMax() -> Element? {
        guard !isEmpty else { return nil }
        if count == 1 { return unsafe _readPointerToElement(at: 0).pointee }
        if count == 2 { return unsafe _readPointerToElement(at: 1).pointee }

        let e1 = unsafe _readPointerToElement(at: 1).pointee
        let e2 = unsafe _readPointerToElement(at: 2).pointee
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Truncate

extension Heap.Small where Element: ~Copyable {
    /// Removes elements beyond the specified count.
    ///
    /// If `newCount >= count`, this method has no effect.
    ///
    /// - Parameter newCount: The maximum number of elements to retain.
    /// - Complexity: O(k) where k is the number of removed elements.
    @inlinable
    public mutating func truncate(to newCount: Int) {
        guard newCount < _count else { return }
        let targetCount = Swift.max(0, newCount)

        if let heap = _heap {
            heap._deinitializeElements(in: targetCount..<_count)
            heap.header = targetCount
        } else {
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
                let basePtr = UnsafeMutableRawPointer(storagePtr)
                for i in targetCount..<_count {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe elementPtr.deinitialize(count: 1)
                }
            }
        }
        _count = targetCount
    }
}

// MARK: - Span Access

extension Heap.Small where Element: ~Copyable {
    /// Read-only span of the heap elements in heap order.
    ///
    /// Elements are in heap order, which is **not** sorted order.
    @inlinable
    public var span: Span<Element> {
        _read {
            if let heapPtr = unsafe _heapPtr {
                yield unsafe Span(_unsafeStart: heapPtr, count: _count)
            } else {
                yield unsafe Span(_unsafeStart: _inlineReadPointerToElement(at: 0), count: _count)
            }
        }
    }

    /// Mutable span of the heap elements.
    ///
    /// - Warning: Modifying elements may break the heap invariant.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        _read {
            if let heapPtr = unsafe _heapPtr {
                yield unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
            } else {
                let ptr = unsafe UnsafeMutablePointer(mutating: _inlineReadPointerToElement(at: 0))
                yield unsafe MutableSpan(_unsafeStart: ptr, count: _count)
            }
        }
        _modify {
            if let heapPtr = unsafe _heapPtr {
                var s = unsafe MutableSpan(_unsafeStart: heapPtr, count: _count)
                yield &s
            } else {
                var s = unsafe MutableSpan(_unsafeStart: _inlineMutableBasePointer(), count: _count)
                yield &s
            }
        }
    }

    /// Returns the mutable inline base pointer.
    @usableFromInline
    @unsafe
    mutating func _inlineMutableBasePointer() -> UnsafeMutablePointer<Element> {
        unsafe Swift.withUnsafeMutablePointer(to: &_inline) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            return unsafe basePtr.assumingMemoryBound(to: Element.self)
        }
    }
}

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

// MARK: - Replace Accessor (Copyable elements only)

extension Heap where Element: Copyable {
    /// Nested accessor for replace operations.
    ///
    /// Replace is more efficient than pop + push when you need to
    /// replace the extremum:
    /// ```swift
    /// var heap: Heap<Int> = [3, 1, 4, 1, 5]
    /// let oldMin = try heap.replace.min(with: 0)  // returns 1, heap now has 0
    /// let oldMax = try heap.replace.max(with: 9)  // returns 5, heap now has 9
    /// ```
    ///
    /// - Note: This accessor is only available for `Copyable` elements.
    @inlinable
    public var replace: Replace {
        _read {
            yield Replace(heap: self)
        }
        _modify {
            // Force uniqueness before transferring
            _makeUnique()

            var proxy = Replace(heap: self)
            self = Heap()  // Clear self to release our reference
            defer { self = proxy.heap }
            yield &proxy
        }
    }
}

// MARK: - Replace Type

extension Heap where Element: Copyable {
    /// Namespace for replace operations.
    public struct Replace {
        @usableFromInline
        var heap: Heap<Element>

        @usableFromInline
        init(heap: Heap<Element>) {
            self.heap = heap
        }
    }
}

// MARK: - Replace Operations

extension Heap.Replace where Element: Copyable {
    /// Replaces the minimum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original minimum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func min(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty(.init())
        }
        return heap._replaceMin(with: replacement)
    }

    /// Replaces the maximum element and returns the old value.
    ///
    /// - Parameter replacement: The new value to insert.
    /// - Returns: The original maximum element.
    /// - Throws: `Heap.Error.empty` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public mutating func max(with replacement: Element) throws(Heap<Element>.Error) -> Element {
        guard !heap.isEmpty else {
            throw .empty(.init())
        }
        return heap._replaceMax(with: replacement)
    }
}

// MARK: - Bounded Heap Index Operations
// NOTE: Per [MEM-COPY-006], protocol conformances and extensions for nested types
// MUST be in the same file as the type declaration to avoid breaking ~Copyable propagation.

extension Heap.Bounded where Element: ~Copyable {
    /// Returns the index of the root element, or nil if the heap is empty.
    @inlinable
    public func rootIndex() -> Heap<Element>.Index? {
        isEmpty ? nil : .zero
    }

    /// Returns whether the given index represents a valid position in the heap.
    @inlinable
    public func isValid(_ index: Heap<Element>.Index) -> Bool {
        index >= .zero && index.position.rawValue < count
    }
}

extension Heap.Bounded where Element: Copyable {
    /// Returns the element at the given typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Heap<Element>.Index) -> Element? {
        guard isValid(index) else { return nil }
        return _storage._readElement(at: index.position.rawValue)
    }
}
