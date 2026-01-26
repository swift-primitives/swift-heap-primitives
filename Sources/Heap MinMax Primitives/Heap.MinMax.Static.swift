//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

import Heap_Primitives_Core

extension Heap.MinMax {
    /// Compile-time capacity min-max heap with inline storage.
    public struct Static<let capacity: Int>: ~Copyable {
        /// Inline storage for elements.
        @usableFromInline
        package var inline: Heap.Storage.Inline<capacity>

        /// Current element count.
        public var count: Heap.Index.Count

        /// Workaround for Swift compiler bug.
        @usableFromInline
        package var _deinitWorkaround: AnyObject? = nil

        /// Creates an empty inline min-max heap.
        @inlinable
        public init() {
            self.inline = Heap.Storage.Inline<capacity>()
            self.count = .zero
        }

        deinit {
            inline.deinitialize(count: count)
        }
    }
}
