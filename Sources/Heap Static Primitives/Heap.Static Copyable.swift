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
public import Buffer_Linear_Primitives


// MARK: - Heap.Static Iterator

extension Heap.Static where Element: Copyable & Comparison.`Protocol` {
    /// Iterator for Heap.Static elements.
    ///
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _buffer: Buffer<Element>.Linear

        @usableFromInline
        let _end: Heap.Index.Count

        @usableFromInline
        var _index: Heap.Index = .zero

        @usableFromInline
        init(_buffer: Buffer<Element>.Linear) {
            self._buffer = _buffer
            self._end = _buffer.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _end else { return nil }
            let element = _buffer[_index]
            _index += .one
            return element
        }
    }
}

extension Heap.Static.Iterator: Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Heap.Static: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Returns an iterator over the heap elements.
    ///
    /// Copies elements to a `Buffer.Linear` snapshot for safe iteration,
    /// avoiding pointer escape issues with inline storage.
    ///
    /// - Note: Elements are yielded in heap order, which is **not** sorted order.
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use
    ///   the mutating `forEach` method instead.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var snapshot = Buffer<Element>.Linear(minimumCapacity: count)
        var idx: Heap.Index = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            snapshot.append(_buffer[idx])
            idx += .one
        }
        return Iterator(_buffer: snapshot)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Sequence.Clearable Conformance

extension Heap.Static: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all()
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.Static: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        var idx: Heap.Index = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            body(_buffer[idx])
            idx += .one
        }
        _buffer.remove.all()
    }
}

// MARK: - Sequence Tag Enums

extension Heap.Static where Element: Copyable & Comparison.`Protocol` {
    public enum Drain {
        public typealias View = Property<Sequence.Drain>.View.Typed<Element>.Valued<capacity>
    }
    public enum ForEach {
        public typealias View = Property<Sequence.ForEach>.View.Typed<Element>.Valued<capacity>
    }
    public enum Satisfies {
        public typealias View = Property<Sequence.Satisfies>.View.Typed<Element>.Valued<capacity>
    }
    public enum First {
        public typealias View = Property<Sequence.First>.View.Typed<Element>.Valued<capacity>
    }
    public enum Reduce {
        public typealias View = Property<Sequence.Reduce>.View.Typed<Element>.Valued<capacity>
    }
    public enum Contains {
        public typealias View = Property<Sequence.Contains>.View.Typed<Element>.Valued<capacity>
    }
    public enum Drop {
        public typealias View = Property<Sequence.Drop>.View.Typed<Element>.Valued<capacity>
    }
    public enum Prefix {
        public typealias View = Property<Sequence.Prefix>.View.Typed<Element>.Valued<capacity>
    }
}

// MARK: - Property Accessors

extension Heap.Static where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drain.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for forEach operations.
    public var forEach: ForEach.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: ForEach.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Satisfies.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Satisfies.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for finding the first matching element.
    public var first: First.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: First.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for reduce operations.
    public var reduce: Reduce.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Reduce.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for containment checks.
    public var contains: Contains.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Contains.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for drop operations.
    public var drop: Drop.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drop.View = unsafe .init(&self); yield &view }
    }

    /// Accessor for prefix operations.
    public var prefix: Prefix.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Prefix.View = unsafe .init(&self); yield &view }
    }
}

// MARK: - Peek (Copyable elements)

extension Heap.Static where Element: Copyable & Comparison.`Protocol` {
    /// Returns the priority element without removing it, or nil if empty.
    ///
    /// - Returns: A copy of the priority element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        mutating get {
            guard !isEmpty else { return nil }
            return _buffer[.zero]
        }
    }
}
