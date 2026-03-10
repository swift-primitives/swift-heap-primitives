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

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

        /// The ordering direction for this heap.
        public let order: Order

        // WORKAROUND: Forces compiler to execute deinit body.
        // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
        // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
        //      with cross-package value-generic stored properties.
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty small heap.
        ///
        /// - Parameter order: The ordering direction. Defaults to `.ascending` (min-heap).
        @inlinable
        public init(order: Order = .ascending) {
            self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
            self.order = order
        }

        deinit {
            // WORKAROUND: Manually clean up elements via the mutating path.
            // TRACKING: swiftlang/swift #86652 variant
            unsafe withUnsafePointer(to: _buffer) { ptr in
                unsafe UnsafeMutablePointer(mutating: ptr).pointee.remove.all()
            }
        }
    }
}

// MARK: - Sendable

extension Heap.Small: @unchecked Sendable where Element: Sendable {}
