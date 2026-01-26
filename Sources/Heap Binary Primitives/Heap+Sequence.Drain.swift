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
        makeUnique()
        (0..<_storage.count).forEach { index in
            body(_storage.move(at: index))
        }
        _storage.header = 0
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
