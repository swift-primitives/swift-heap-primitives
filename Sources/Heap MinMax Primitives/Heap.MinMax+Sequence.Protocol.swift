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

public import Heap_Primitives_Core
public import Sequence_Primitives
public import Property_Primitives
public import Range_Primitives

// MARK: - Sequence.Protocol Conformance

extension Heap.MinMax: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // makeIterator() is provided by Swift.Sequence conformance in Heap.MinMax Copyable.swift

    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { _storage.header }
}

// MARK: - Sequence.Clearable Conformance

extension Heap.MinMax: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all(keepingCapacity: false)
    }
}

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.MinMax: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        makeUnique()
        (0..<_storage.count).forEach { index in
            body(_storage.move(at: index))
        }
        _storage.header = 0
    }
}

// MARK: - Property Accessors

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain>.View(&self)
            yield &view
        }
    }

    /// Accessor for forEach operations.
    public var forEach: Property<Sequence.ForEach>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach>.View(&self)
            yield &view
        }
    }

    /// Accessor for predicate satisfaction checks.
    public var satisfies: Property<Sequence.Satisfies>.View {
        mutating _read {
            yield unsafe Property<Sequence.Satisfies>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Satisfies>.View(&self)
            yield &view
        }
    }

    /// Accessor for finding the first matching element.
    public var first: Property<Sequence.First>.View {
        mutating _read {
            yield unsafe Property<Sequence.First>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.First>.View(&self)
            yield &view
        }
    }

    /// Accessor for reduce operations.
    public var reduce: Property<Sequence.Reduce>.View {
        mutating _read {
            yield unsafe Property<Sequence.Reduce>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Reduce>.View(&self)
            yield &view
        }
    }

    /// Accessor for containment checks.
    public var contains: Property<Sequence.Contains>.View {
        mutating _read {
            yield unsafe Property<Sequence.Contains>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Contains>.View(&self)
            yield &view
        }
    }

    /// Accessor for drop operations.
    public var drop: Property<Sequence.Drop>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drop>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drop>.View(&self)
            yield &view
        }
    }

    /// Accessor for prefix operations.
    public var prefix: Property<Sequence.Prefix>.View {
        mutating _read {
            yield unsafe Property<Sequence.Prefix>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Prefix>.View(&self)
            yield &view
        }
    }
}
