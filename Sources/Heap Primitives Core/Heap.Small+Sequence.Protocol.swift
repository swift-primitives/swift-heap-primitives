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
    /// Iterator for Heap.Small elements.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _inline: Heap.Storage.Inline<inlineCapacity>

        @usableFromInline
        let _heap: Heap.Storage?

        @usableFromInline
        let _heapPtr: Heap.Pointer?

        @usableFromInline
        let _end: Heap.Index.Count

        @usableFromInline
        var _index: Heap.Index = .zero

        @usableFromInline
        init(
            _inline: Heap.Storage.Inline<inlineCapacity>,
            _heap: Heap.Storage?,
            _heapPtr: Heap.Pointer?,
            count: Heap.Index.Count
        ) {
            self._inline = _inline
            self._heap = _heap
            self._heapPtr = _heapPtr
            self._end = count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _end else { return nil }
            defer { _index = (_index + 1)! }
            if let ptr = _heapPtr {
                return unsafe ptr[_index.position.rawValue]
            } else {
                return unsafe _inline.read(at: _index).pointee
            }
        }
    }
}

// MARK: - Sequence.Protocol Conformance

extension Heap.Small: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Returns an iterator over the heap's elements in heap order.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inline: inline, _heap: heap, _heapPtr: heapPtr, count: count)
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
