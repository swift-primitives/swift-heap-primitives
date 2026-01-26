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

public import Sequence_Primitives
public import Property_Primitives
public import Range_Primitives

// MARK: - Heap.Small Iterator

extension Heap.Small where Element: Copyable & Comparison.`Protocol` {
    /// Pointer-based iterator for Heap.Small elements.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to either inline or heap storage.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source heap exists and is not mutated.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let base: UnsafePointer<Element>

        @usableFromInline
        let end: Heap.Index.Count

        @usableFromInline
        var position: Heap.Index

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Heap.Index.Count) {
            unsafe self.base = base
            self.end = count
            self.position = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < end else { return nil }
            let result = unsafe base[position]
            position = (position + 1)!
            return result
        }
    }
}

extension Heap.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Heap.Small: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Returns a pointer-based iterator over the heap elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    ///
    /// ## Implementation Note
    ///
    /// This function must be `borrowing` (non-mutating) per Sequence protocol.
    /// For heap storage, we use the cached `heapPtr` pointer directly.
    /// For inline storage, we use `withUnsafePointer(to:)` on the stored property
    /// to obtain a pointer without requiring `&self`.
    ///
    /// The `inline` accessor cannot be used here because it requires `mutating`
    /// context (needs `&self` to construct the accessor struct). See:
    /// `/Users/coen/Developer/swift-institute/Research/Non-Mutating-Accessor-Problem.md`
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        guard count.rawValue > 0 else {
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }

        if let ptr = heapPtr {
            return unsafe Iterator(base: UnsafePointer(ptr), count: count)
        } else {
            // Inline storage - get pointer to first element via withUnsafePointer
            // Note: We use withUnsafePointer directly on the stored property because
            // the `inline` accessor requires mutating context (needs &self).
            _ = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                return unsafe Iterator(base: elementPtr, count: count)
            }
        }
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count.rawValue }
}

// MARK: - Sequence.Clearable Conformance

extension Heap.Small: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// Does not shrink back to inline storage if spilled.
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all()
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.Small: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    /// Does not shrink back to inline storage if spilled.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        (0..<count).forEach { index in
            body(unsafe pointer(at: index).move())
        }
        count = .zero
        if let heapStorage = heap {
            heapStorage.header = 0
        }
    }
}

// MARK: - Property Accessors

extension Heap.Small where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drain>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for forEach operations.
    public var forEach: Property<Sequence.ForEach>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Property<Sequence.Satisfies>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Satisfies>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Satisfies>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for finding the first matching element.
    public var first: Property<Sequence.First>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.First>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.First>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for reduce operations.
    public var reduce: Property<Sequence.Reduce>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Reduce>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Reduce>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for containment checks.
    public var contains: Property<Sequence.Contains>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Contains>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Contains>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for drop operations.
    public var drop: Property<Sequence.Drop>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drop>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drop>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }

    /// Accessor for prefix operations.
    public var prefix: Property<Sequence.Prefix>.View.Typed<Element>.Valued<inlineCapacity> {
        mutating _read {
            yield unsafe Property<Sequence.Prefix>.View.Typed<Element>.Valued(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Prefix>.View.Typed<Element>.Valued<inlineCapacity>(&self)
            yield &view
        }
    }
}
