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

public import Heap_Primitive

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
    ///
    /// ## Iteration
    ///
    /// `Heap.Min` is a stub with no backing storage; it therefore carries no
    /// iteration surface (no `Memory.Contiguous.Protocol` / `Iterable` /
    /// `Sequenceable`). These conformances arrive when the type is realized.
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

/// Sendable conformance for `Heap.Min` (stub; `Heap` is the realized form).
///
/// ## Safety Invariant
///
/// `Heap.Min` is `~Copyable`; unique ownership will be the safety model
/// once the type is implemented. The Sendable form matches `Heap`.
///
/// ## Intended Use
///
/// - Placeholder for a dedicated single-ended min-heap once implemented.
/// - Consumers should use `Heap` with `.ascending` ordering until then.
///
/// ## Non-Goals
///
/// - Not functional today; init traps.
/// - No synchronization; same constraints as `Heap` will apply.
extension Heap.Min: @unsafe @unchecked Sendable where Element: Sendable {}
