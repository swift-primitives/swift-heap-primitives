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

extension Heap.Static: @unchecked Sendable where Element: Sendable {}
