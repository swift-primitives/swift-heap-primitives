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
import Storage_Heap_Primitives
public import Buffer_Linear_Small_Primitive

extension Heap.MinMax {
    /// Min-max heap with small-buffer optimization.
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Errors that can occur during small min-max heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        /// Element cleanup is handled by Storage.Inline's deinit (inline path) or Storage.Contiguous<Memory.Heap>'s deinit (spilled path).

        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Small<inlineCapacity>

        /// Creates an empty small min-max heap.
        @inlinable
        public init() {
            self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Small<inlineCapacity>()
        }
    }
}
