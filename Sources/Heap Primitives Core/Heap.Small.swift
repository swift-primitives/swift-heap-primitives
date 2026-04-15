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

import Buffer_Linear_Small_Primitives

extension Heap where Element: ~Copyable {

    // MARK: - Small (Small-Buffer Optimization)

    /// A binary heap with small-buffer optimization (SmallVec pattern).
    ///
    /// `Heap.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Errors that can occur during small heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        /// Element cleanup is handled by Storage.Inline's deinit (inline path) or Storage.Heap's deinit (spilled path).

        /// The ordering direction for this heap.
        public let order: Order

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// Creates an empty small heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
            self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
            self.order = order
        }
    }
}

// MARK: - Sendable

/// Sendable conformance for `Heap.Small`.
///
/// ## Safety Invariant
///
/// `Heap.Small` is unconditionally `~Copyable` (inline storage with
/// automatic heap spill). Unique ownership ensures the move across
/// threads relinquishes the sender's access; both the inline bytes and
/// any spilled allocation transfer together.
///
/// ## Intended Use
///
/// - SmallVec-style priority queue handed from builder to consumer where
///   typical workloads fit inline but can spill.
/// - Transferring small-size-optimized heaps of `~Copyable` elements
///   without forcing heap allocation for common cases.
///
/// ## Non-Goals
///
/// - Not safe for concurrent mutation on either the inline or spilled
///   path; single-owner is the only supported model.
/// - Spill transitions are not atomic with respect to external observers.
extension Heap.Small: @unsafe @unchecked Sendable where Element: Sendable {}
