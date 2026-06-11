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

public import Buffer_Linear_Primitives
public import Column_Primitives
import Storage_Contiguous_Primitives
public import Heap_Primitive

extension Heap where Element: ~Copyable {
    /// A result builder for declaratively constructing heaps with O(n) heapification.
    ///
    /// The builder collects elements into a linear intermediate buffer; the
    /// convenience init drains the buffer into a fresh `Heap` via the
    /// internal `appendWithoutHeapify` + `heapify()` path, giving an
    /// overall O(n) construction cost — strictly better than the
    /// O(n log n) push-by-push path.
    ///
    /// The order parameter binds at the outer convenience init, not in the
    /// builder body:
    ///
    /// ```swift
    /// // Min-heap (default .ascending)
    /// let minHeap = Heap<Int> {
    ///     5
    ///     1
    ///     3
    ///     2
    /// }
    /// minHeap.peek  // 1 — minimum
    ///
    /// // Max-heap (explicit .descending)
    /// let maxHeap = Heap<Int>(order: .descending) {
    ///     5
    ///     1
    ///     3
    ///     2
    /// }
    /// maxHeap.peek  // 5 — maximum
    /// ```
    ///
    /// Supports `~Copyable` elements via consuming append; the heapify
    /// path uses move semantics throughout.
    ///
    /// ## `for` Loops Not Supported
    ///
    /// `buildArray` is omitted because Swift's result-builder transform's
    /// buildArray step uses `Swift.Array<Component>`, which currently
    /// requires `Component: Copyable`. The component here is the
    /// ~Copyable `Column.Heap<Element>`.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element
        ) -> Column.Heap<Element> {
            var result = Column.Heap<Element>(minimumCapacity: .one)
            result.append(consume expression)
            return result
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            consume expression
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element?
        ) -> Column.Heap<Element> {
            var result = Column.Heap<Element>(minimumCapacity: .zero)
            if let value = consume expression {
                result.append(consume value)
            }
            return result
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(
            first: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            consume first
        }

        @inlinable
        public static func buildPartialBlock(
            first: Void
        ) -> Column.Heap<Element> {
            Column.Heap<Element>(minimumCapacity: .zero)
        }

        @inlinable
        public static func buildPartialBlock(
            first: Never
        ) -> Column.Heap<Element> {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: consuming Column.Heap<Element>,
            next: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            var result = consume accumulated
            var rest = consume next
            while !rest.isEmpty {
                result.append(rest.remove.first())
            }
            return result
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> Column.Heap<Element> {
            Column.Heap<Element>(minimumCapacity: .zero)
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(
            _ component: consuming Column.Heap<Element>?
        ) -> Column.Heap<Element> {
            if let result = consume component {
                return consume result
            }
            return Column.Heap<Element>(minimumCapacity: .zero)
        }

        @inlinable
        public static func buildEither(
            first: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            consume first
        }

        @inlinable
        public static func buildEither(
            second: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            consume second
        }

        // buildArray omitted: see DocC above.

        @inlinable
        public static func buildLimitedAvailability(
            _ component: consuming Column.Heap<Element>
        ) -> Column.Heap<Element> {
            consume component
        }
    }
}

// MARK: - Convenience Init (Copyable twins — the clone-capturing sites)

// The grammar's accumulator is a RAW column (no `Shared` box), so the grammar
// functions are lane-agnostic; construction of the HEAP happens here, in the
// convenience init's `self.init(order:)` call. Spelled in a `~Copyable`
// generic context that call statically resolves to the drain-only
// constructor, so a `Copyable`-element heap built there would escape with a
// box that cannot restore uniqueness (the first CoW gate after a copy would
// trap). The `Copyable` twin re-binds the inner init to the clone-capturing
// lane; at `Copyable` call sites the more-constrained twin wins.

extension Heap where Element: ~Copyable {
    /// Constructs a heap from a result-builder closure with O(n) heapification.
    ///
    /// The order parameter binds here at the outer init — the builder body
    /// declares element values, not heap order. Internally collects elements
    /// in a linear buffer, then drains them into the heap via
    /// `appendWithoutHeapify` followed by a single `heapify()` call.
    ///
    /// ```swift
    /// let minHeap = Heap<Int> {
    ///     5
    ///     1
    ///     3
    /// }
    /// // peek == 1 (min-heap default)
    ///
    /// let maxHeap = Heap<Int>(order: .descending) {
    ///     5
    ///     1
    ///     3
    /// }
    /// // peek == 5 (max-heap)
    /// ```
    ///
    /// - Complexity: O(n) where n is the number of elements declared.
    @inlinable
    public init(
        order: Order = .ascending,
        @Heap.Builder _ builder: () -> Column.Heap<Element>
    ) {
        var buffer = builder()
        self.init(order: order)
        while !buffer.isEmpty {
            appendWithoutHeapify(buffer.remove.first())
        }
        if count > .one {
            heapify()
        }
    }
}

extension Heap where Element: Copyable {
    /// Constructs a heap from a result-builder closure with O(n) heapification
    /// (the `Copyable` constructing twin — the inner `init(order:)` resolves
    /// to the clone-capturing constructor, so the escaping heap's CoW box can
    /// restore uniqueness).
    ///
    /// - Complexity: O(n) where n is the number of elements declared.
    @inlinable
    public init(
        order: Order = .ascending,
        @Heap.Builder _ builder: () -> Column.Heap<Element>
    ) {
        var buffer = builder()
        self.init(order: order)
        while !buffer.isEmpty {
            appendWithoutHeapify(buffer.remove.first())
        }
        if count > .one {
            heapify()
        }
    }
}

// MARK: - Sequence Bulk-Add (Copyable Element only)

extension Heap.Builder where Element: Copyable {
    /// Bulk-add a Swift.Sequence without per-iteration allocation. The
    /// resulting elements are heapified in O(n) by the convenience init.
    @inlinable
    public static func buildExpression<S: Swift.Sequence>(_ expression: S) -> Column.Heap<Element>
    where S.Element == Element {
        var result = Column.Heap<Element>(minimumCapacity: .zero)
        for value in expression {
            result.append(value)
        }
        return result
    }
}
