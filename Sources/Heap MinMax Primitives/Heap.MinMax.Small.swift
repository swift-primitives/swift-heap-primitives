//
//  File.swift
//  swift-heap-primitives
//
//  Created by Coen ten Thije Boonkkamp on 26/01/2026.
//

extension Heap.MinMax {
    /// Min-max heap with small-buffer optimization.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Inline storage for elements.
        @usableFromInline
        package var inline: Heap.Storage.Inline<inlineCapacity>

        /// Current element count (valid elements in either inline or heap storage).
        public var count: Heap.Index.Count

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var heap: Heap.Storage?

        /// Cached pointer to heap elements. Only valid when heap is non-nil.
        @usableFromInline
        package var heapPtr: UnsafeMutablePointer<Element>?

        /// Creates an empty small min-max heap.
        @inlinable
        public init() {
            self.inline = Heap.Storage.Inline<inlineCapacity>()
            self.count = .zero
            self.heap = nil
            unsafe self.heapPtr = nil
        }

        deinit {
            guard count > .zero else { return }

            if let heapState = heap {
                heapState.header = count.rawValue
            } else {
                inline.deinitialize(count: count)
            }
        }
    }
}
