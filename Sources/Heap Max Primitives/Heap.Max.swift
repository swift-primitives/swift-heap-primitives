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
    /// Single-ended max-heap (stub - not yet implemented).
    ///
    /// A max-heap provides O(1) access to the maximum element and O(log n)
    /// insertion and removal of the maximum. Unlike the double-ended
    /// `Heap`, this type only provides access to the maximum.
    ///
    /// ## Status
    ///
    /// This type is a placeholder. Use ``Heap`` for a fully-implemented
    /// double-ended min-max heap.
    public struct Max: ~Copyable {
        // TODO: Implement max-only heap

        /// Creates an empty max-heap.
        @inlinable
        public init() {
            fatalError("Heap.Max is not yet implemented. Use Heap instead.")
        }
    }
}

// MARK: - Conditional Copyable

extension Heap.Max: Copyable where Element: Copyable {}

// MARK: - Sendable

/// Sendable conformance for `Heap.Max` (stub; `Heap` is the realized form).
///
/// ## Safety Invariant
///
/// `Heap.Max` is `~Copyable`; unique ownership will be the safety model
/// once the type is implemented. The Sendable form matches `Heap`.
///
/// ## Intended Use
///
/// - Placeholder for a dedicated single-ended max-heap once implemented.
/// - Consumers should use `Heap` with `.descending` ordering until then.
///
/// ## Non-Goals
///
/// - Not functional today; init traps.
/// - No synchronization; same constraints as `Heap` will apply.
extension Heap.Max: Sendable where Element: Sendable {}
