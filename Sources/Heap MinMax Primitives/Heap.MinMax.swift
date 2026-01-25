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
    /// Double-ended min-max heap (stub - not yet implemented).
    ///
    /// This is a placeholder for an alternative min-max heap implementation.
    /// The current implementation is available as ``Heap``.
    ///
    /// ## Status
    ///
    /// This type is a placeholder. Use ``Heap`` for a fully-implemented
    /// double-ended min-max heap.
    public struct MinMax: ~Copyable {
        // TODO: Implement alternative min-max heap

        /// Creates an empty min-max heap.
        @inlinable
        public init() {
            fatalError("Heap.MinMax is not yet implemented. Use Heap instead.")
        }
    }
}

// MARK: - Conditional Copyable

extension Heap.MinMax: Copyable where Element: Copyable {}

// MARK: - Sendable

extension Heap.MinMax: @unchecked Sendable where Element: Sendable {}
