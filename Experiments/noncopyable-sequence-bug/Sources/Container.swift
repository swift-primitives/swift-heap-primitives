// ===----------------------------------------------------------------------===//
// Experiment: noncopyable-sequence-bug
// Date: 2026-01-20
// Swift Version: 6.2.3
// ===----------------------------------------------------------------------===//
//
// RESULT: CONFIRMED - Swift Compiler Bug Isolated
//
// EXACT TRIGGER CONDITIONS (ALL required):
// =========================================
// 1. Generic type with COMPOUND constraint: `Element: ~Copyable & Protocol`
//    (Single constraint `Element: ~Copyable` does NOT trigger the bug)
//
// 2. Nested type contains `UnsafeMutablePointer<Element>` stored property
//
// 3. Conditional Sequence conformance: `where Element: Copyable`
//    (Other conditional conformances do NOT trigger the bug)
//
// 4. Extension FILE (separate .swift file) contains method with
//    `(borrowing Element)` closure parameter
//    (Same method in the main file does NOT trigger the bug)
//
// ERROR MESSAGE:
// error: type 'Element' does not conform to protocol 'Copyable'
// var _cachedPtr: UnsafeMutablePointer<Element>
//
// WORKAROUND:
// - Disable Sequence conformance and provide `forEach(_:)` alternative
// - Or move borrowing Element methods to the main type file
//
// BUG CATEGORY: Module Emission Phase Constraint Propagation Failure
// This is a Category 4 failure beyond MEM-COPY-006 documented patterns.
// ===----------------------------------------------------------------------===//

// MARK: - Protocol with borrowing comparison (mimics __HeapOrdering)

public protocol Ordering: ~Copyable {
    static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

extension Ordering where Self: Comparable {
    public static func isLessThan(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs < rhs
    }
}

extension Int: Ordering {}

// MARK: - Container with compound constraint

@safe
public struct Container<Element: ~Copyable & Ordering>: ~Copyable {

    // Nested Storage class (inherits ~Copyable context)
    @usableFromInline
    final class Storage: ManagedBuffer<Int, Element> {
        @usableFromInline
        static func create() -> Storage {
            let storage = Storage.create(minimumCapacity: 4) { _ in 0 }
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

        @usableFromInline
        var _elementsPointer: UnsafeMutablePointer<Element> {
            unsafe withUnsafeMutablePointerToElements { unsafe $0 }
        }

        @usableFromInline
        func _readElement(at index: Int) -> Element where Element: Copyable {
            unsafe withUnsafeMutablePointerToElements { elements in
                unsafe elements[index]
            }
        }

        @usableFromInline
        func _initializeElement(at index: Int, to element: consuming Element) {
            let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
            unsafe ptr.initialize(to: element)
        }
    }

    @usableFromInline
    var _storage: Storage

    @usableFromInline
    var _cachedPtr: UnsafeMutablePointer<Element>

    public init() {
        self._storage = Storage.create()
        unsafe (self._cachedPtr = _storage._elementsPointer)
    }

    // MARK: - Nested Bounded type (same pattern as Heap.Bounded)

    @safe
    public struct Bounded: ~Copyable {
        @usableFromInline
        var _storage: Storage

        // ERROR APPEARS HERE during module emission when all trigger conditions met
        @usableFromInline
        var _cachedPtr: UnsafeMutablePointer<Element>

        public let capacity: Int

        @inlinable
        public init(capacity: Int) {
            self._storage = Storage.create()
            unsafe (self._cachedPtr = _storage._elementsPointer)
            self.capacity = capacity
        }

        // Push.Outcome nested enum - also shows error on `overflow(Element)`
        public enum Push: ~Copyable {
            public enum Outcome: ~Copyable {
                case inserted
                case overflow(Element)
            }
        }
    }
}

// MARK: - Conditional Copyable

extension Container: Copyable where Element: Copyable {}
extension Container.Bounded: Copyable where Element: Copyable {}
extension Container.Bounded.Push.Outcome: Copyable where Element: Copyable {}

// MARK: - Sequence Conformance (TRIGGER CONDITION #3)
//
// This conformance, combined with `borrowing Element` closures in a separate
// extension file (Container.Bounded.swift), triggers the bug.

extension Container.Bounded: Sequence where Element: Copyable {
    public func makeIterator() -> AnyIterator<Element> {
        var index = 0
        let storage = _storage
        return AnyIterator {
            guard index < storage.header else { return nil }
            defer { index += 1 }
            return storage._readElement(at: index)
        }
    }
}

