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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
import Storage_Heap_Primitives
public import Buffer_Linear_Inline_Primitive

extension Heap.MinMax {
    /// Compile-time capacity min-max heap with inline storage.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Errors that can occur during static min-max heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        /// Element cleanup is handled by Storage.Inline's deinit.

        @usableFromInline
        package var _buffer: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Inline<capacity>

        /// Creates an empty inline min-max heap.
        @inlinable
        public init() {
            self._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Inline<capacity>()
        }
    }
}
