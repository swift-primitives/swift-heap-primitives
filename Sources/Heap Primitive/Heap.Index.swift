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

public import Index_Primitives

extension Heap where Element: ~Copyable {
    /// Type-safe index for heap elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Heap Index Semantics
    ///
    /// Position 0 is the root of the heap. For a min-max heap:
    /// - Even levels (0, 2, 4, ...) are min levels
    /// - Odd levels (1, 3, 5, ...) are max levels
    ///
    /// Parent-child relationships follow binary heap structure:
    /// - Parent of node at `i`: `(i - 1) / 2`
    /// - Children of node at `i`: `2i + 1` and `2i + 2`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let heapIdx: Heap<Int>.Index = 0
    /// // Get root element via index
    /// ```
    public typealias Index = Index_Primitives.Index<Element>
}
