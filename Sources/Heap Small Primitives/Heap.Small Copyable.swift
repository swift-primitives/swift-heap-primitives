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
public import Pointer_Primitives

// MARK: - Heap.Small Iterator

extension Heap.Small where Element: Copyable & Comparison.`Protocol` {
    /// Array-based iterator for Heap.Small elements.
    ///
    /// Copies elements to an internal array for safe iteration. This avoids
    /// the pointer escape issues that occur with inline storage.
    ///
    /// - Note: For heap storage, iteration could be zero-copy, but we use
    ///   a consistent approach for simplicity.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var elements: [Element]

        @usableFromInline
        var position: Int

        @usableFromInline
        init(elements: [Element]) {
            self.elements = elements
            self.position = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < elements.count else { return nil }
            let result = elements[position]
            position += 1
            return result
        }
    }
}

extension Heap.Small.Iterator: Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Heap.Small: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Returns an iterator over the heap elements.
    ///
    /// Copies elements to an array for safe iteration. This avoids pointer
    /// escape issues with inline storage.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use
    ///   the mutating `forEach` method instead.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        guard count.rawValue > 0 else {
            return Iterator(elements: [])
        }

        // Copy elements to array for safe iteration
        var elements: [Element] = []
        elements.reserveCapacity(count.rawValue)

        if let ptr = heapPtr {
            // Heap storage: stable pointer, direct access is safe
            (0..<count.rawValue).forEach { position in
                let index = Heap.Index(__unchecked: (), position: position)
                elements.append(ptr[index])
            }
        } else {
            // Inline storage: copy using direct access within borrowing scope
            let stride = MemoryLayout<Element>.stride
            unsafe Swift.withUnsafePointer(to: inline.raw) { rawPointer in
                let base = unsafe UnsafeRawPointer(rawPointer)
                (0..<count.rawValue).forEach { position in
                    let ptr = unsafe (base + position * stride).assumingMemoryBound(to: Element.self)
                    unsafe elements.append(ptr.pointee)
                }
            }
        }
        return Iterator(elements: elements)
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
            unsafe withPointer(at: index) { ptr in
                body(ptr.move())
            }
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
