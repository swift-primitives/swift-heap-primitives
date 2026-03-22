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

        // WORKAROUND: swiftlang/swift#86652 — @_rawLayout triviality misclassification.
        // Forces compiler to recognize type as non-trivially destructible so deinit executes.
        // COST: 8 bytes overhead per instance.
        // REMOVAL TEST: swift-buffer-primitives/Experiments/rawlayout-access-level-trigger/
        //   Build with `public` access under -O. If it passes, remove this field
        //   and the manual cleanup in deinit.
        // TRACKING: swift-buffer-primitives/Research/rawlayout-release-crash-investigation.md
        //
        // NOTE: Must be declared BEFORE _buffer. The buffer transitively
        // contains @_rawLayout storage which must be last in memory layout.
        // See Storage.Inline for the Swift 6.2.4 IRGen crash details.
        private var _deinitWorkaround: AnyObject? = nil

        @usableFromInline
        package var _buffer: Buffer<Element>.Linear.Inline<capacity>

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
