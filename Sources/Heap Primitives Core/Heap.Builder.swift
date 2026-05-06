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
    /// ~Copyable `Buffer<Element>.Linear`.
    @resultBuilder
    public enum Builder {

        // MARK: - Expression Building

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element
        ) -> Buffer<Element>.Linear {
            var result = Buffer<Element>.Linear(minimumCapacity: .one)
            result.append(consume expression)
            return result
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            consume expression
        }

        @inlinable
        public static func buildExpression(
            _ expression: consuming Element?
        ) -> Buffer<Element>.Linear {
            var result = Buffer<Element>.Linear(minimumCapacity: .zero)
            if let value = consume expression {
                result.append(consume value)
            }
            return result
        }

        // MARK: - Partial Block Building

        @inlinable
        public static func buildPartialBlock(
            first: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            consume first
        }

        @inlinable
        public static func buildPartialBlock(
            first: Void
        ) -> Buffer<Element>.Linear {
            Buffer<Element>.Linear(minimumCapacity: .zero)
        }

        @inlinable
        public static func buildPartialBlock(
            first: Never
        ) -> Buffer<Element>.Linear {}

        @inlinable
        public static func buildPartialBlock(
            accumulated: consuming Buffer<Element>.Linear,
            next: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            var result = consume accumulated
            var rest = consume next
            while !rest.isEmpty {
                result.append(rest.remove.first())
            }
            return result
        }

        // MARK: - Block Building

        @inlinable
        public static func buildBlock() -> Buffer<Element>.Linear {
            Buffer<Element>.Linear(minimumCapacity: .zero)
        }

        // MARK: - Control Flow

        @inlinable
        public static func buildOptional(
            _ component: consuming Buffer<Element>.Linear?
        ) -> Buffer<Element>.Linear {
            if let result = consume component {
                return consume result
            }
            return Buffer<Element>.Linear(minimumCapacity: .zero)
        }

        @inlinable
        public static func buildEither(
            first: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            consume first
        }

        @inlinable
        public static func buildEither(
            second: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            consume second
        }

        // buildArray omitted: see DocC above.

        @inlinable
        public static func buildLimitedAvailability(
            _ component: consuming Buffer<Element>.Linear
        ) -> Buffer<Element>.Linear {
            consume component
        }
    }
}

// MARK: - Convenience Init

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
        @Heap.Builder _ builder: () -> Buffer<Element>.Linear
    ) {
        var buffer = builder()
        self.order = order
        self._buffer = Buffer<Element>.Linear(minimumCapacity: buffer.count)
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
    public static func buildExpression<S: Swift.Sequence>(_ expression: S) -> Buffer<Element>.Linear
    where S.Element == Element {
        var result = Buffer<Element>.Linear(minimumCapacity: .zero)
        for value in expression {
            result.append(value)
        }
        return result
    }
}
