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

import Buffer_Linear_Inline_Primitives

extension Heap where Element: ~Copyable {

    // MARK: - Static (Fixed-Capacity, Inline Storage)

    /// A fixed-capacity, inline-storage binary heap with compile-time capacity.
    ///
    /// `Heap.Static` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Errors that can occur during static heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        /// Element cleanup is handled by Storage.Inline's deinit.

        /// The ordering direction for this heap.
        public let order: Order

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        /// Creates an empty inline heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
            self.order = order
        }
    }
}

// MARK: - Sendable

/// Sendable conformance for `Heap.Static`.
///
/// ## Safety Invariant
///
/// `Heap.Static` is unconditionally `~Copyable` (inline `@_rawLayout`
/// storage). Unique ownership ensures cross-thread transfer via move is
/// race-free; the inline element bytes travel with the struct.
///
/// ## Intended Use
///
/// - Stack-allocated priority queue moved from constructor to consumer
///   without heap allocation.
/// - Embedded contexts where the compile-time capacity matches a known
///   workload and the heap crosses one isolation boundary during setup.
///
/// ## Non-Goals
///
/// - Not a shared buffer — inline storage is tied to one owner at a time.
/// - No synchronization; mutating access must remain single-threaded.
extension Heap.Static: @unsafe @unchecked Sendable where Element: Sendable {}
