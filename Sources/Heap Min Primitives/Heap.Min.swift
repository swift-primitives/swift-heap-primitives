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

extension Heap where Element: ~Copyable {
    /// Single-ended min-heap (stub - not yet implemented).
    ///
    /// A min-heap provides O(1) access to the minimum element and O(log n)
    /// insertion and removal of the minimum. Unlike the double-ended
    /// `Heap`, this type only provides access to the minimum.
    ///
    /// ## Status
    ///
    /// This type is a placeholder. Use ``Heap`` for a fully-implemented
    /// double-ended min-max heap.
    public struct Min: ~Copyable {
        // TODO: Implement min-only heap

        /// Creates an empty min-heap.
        @inlinable
        public init() {
            fatalError("Heap.Min is not yet implemented. Use Heap instead.")
        }
    }
}

// MARK: - Conditional Copyable

extension Heap.Min: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Heap.Min: @unchecked Sendable where Element: Sendable {}
