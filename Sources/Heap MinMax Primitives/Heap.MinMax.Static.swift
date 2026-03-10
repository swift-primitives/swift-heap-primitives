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

import Heap_Primitives_Core

extension Heap.MinMax {
    /// Compile-time capacity min-max heap with inline storage.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Errors that can occur during static min-max heap operations.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// An operation was attempted on an empty heap.
            case empty
        }

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

        // WORKAROUND: Forces compiler to execute deinit body.
        // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
        // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
        //      with cross-package value-generic stored properties.
        private var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline min-max heap.
        @inlinable
        public init() {
            self._buffer = Buffer<Element>.Linear.Inline<capacity>()
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
