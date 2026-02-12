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
public import Heap_Primitives_Core


// MARK: - Sequence.Protocol Conformance

extension Heap: Sequence.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // makeIterator() is provided by Swift.Sequence conformance in Heap Copyable.swift

    /// Returns the count as the underestimated count since we know the exact size.
    ///
    /// This explicit implementation resolves ambiguity between Swift.Sequence
    /// and Sequence.Protocol+Swift.Sequence default implementation.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Sequence.Clearable Conformance

extension Heap: Sequence.Clearable where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.View` extension.
    @inlinable
    public mutating func removeAll() {
        remove.all(keepingCapacity: false)
    }
}


// MARK: - Sequence Property Accessors

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for forEach operations.
    ///
    /// Provides iteration patterns via `Property.View` extensions:
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.forEach { print($0) }           // borrowing iteration
    /// heap.forEach.borrowing { print($0) } // explicit borrowing
    /// heap.forEach.consuming { print($0) } // consuming (clears heap)
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.satisfies.all { $0 > 0 }   // true
    /// heap.satisfies.any { $0 > 5 }   // true
    /// heap.satisfies.none { $0 < 0 }  // true
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.first { $0 > 5 }  // Optional(8)
    /// heap.first { $0 > 10 } // nil
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// let sum = heap.reduce.into(0) { $0 += $1 }  // 17
    /// let product = heap.reduce.from(1) { $0 * $1 } // 120
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.contains { $0 == 3 }  // true
    /// heap.contains { $0 > 10 }  // false
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1, 2]
    /// heap.drop.first(2)       // [remaining 3 elements]
    /// heap.drop.while { $0 < 5 } // [elements starting from first >= 5]
    /// ```
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
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1, 2]
    /// heap.prefix.first(3)         // [first 3 elements]
    /// heap.prefix.while { $0 < 10 } // [elements while predicate holds]
    /// ```
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

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _buffer.ensureUnique()
        while !_buffer.isEmpty {
            body(_buffer.removeLast())
        }
    }
}

// MARK: - Drain Property Accessor

extension Heap where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    ///
    /// Draining removes all elements from the heap, passing each to a closure
    /// with ownership transferred. The heap survives but is empty after draining.
    ///
    /// ```swift
    /// var heap: Heap<Int> = [5, 3, 8, 1]
    /// heap.drain { element in
    ///     print(element)  // ownership transferred
    /// }
    /// // heap is now empty but still usable
    /// heap.push(10)  // OK
    /// ```
    public var drain: Property<Sequence.Drain>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain>.View(&self)
            yield &view
        }
    }
}
