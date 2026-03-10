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

import Testing
@testable import Heap_Primitives

@Suite("Heap - Deinit")
struct HeapDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitCount: Int { _storage.count }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedElement: ~Copyable, Comparison_Primitives.Comparison.`Protocol` {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
        static func < (lhs: borrowing TrackedElement, rhs: borrowing TrackedElement) -> Bool {
            lhs.id < rhs.id
        }
        static func == (lhs: borrowing TrackedElement, rhs: borrowing TrackedElement) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Heap.Static

    @Test("Static deinit destroys all elements")
    func staticDeinitDestroysAllElements() {
        let tracker = Tracker()
        do {
            var heap = Heap<TrackedElement>.Static<8>(order: .ascending)
            _ = heap.push(TrackedElement(1, tracker: tracker))
            _ = heap.push(TrackedElement(2, tracker: tracker))
            _ = heap.push(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test("Static empty deinit does not crash")
    func staticEmptyDeinitDoesNotCrash() {
        do {
            let _ = Heap<TrackedElement>.Static<8>(order: .ascending)
        }
    }

    // MARK: - Heap.Small

    @Test("Small deinit destroys all elements in inline mode")
    func smallDeinitDestroysAllElementsInInlineMode() {
        let tracker = Tracker()
        do {
            var heap = Heap<TrackedElement>.Small<4>(order: .ascending)
            heap.push(TrackedElement(1, tracker: tracker))
            heap.push(TrackedElement(2, tracker: tracker))
            heap.push(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test("Small deinit destroys all elements after spill")
    func smallDeinitDestroysAllElementsAfterSpill() {
        let tracker = Tracker()
        do {
            var heap = Heap<TrackedElement>.Small<2>(order: .ascending)
            heap.push(TrackedElement(1, tracker: tracker))
            heap.push(TrackedElement(2, tracker: tracker))
            // Spill to heap
            heap.push(TrackedElement(3, tracker: tracker))
            heap.push(TrackedElement(4, tracker: tracker))
        }
        #expect(tracker.deinitCount == 4)
    }

    @Test("Small empty deinit does not crash")
    func smallEmptyDeinitDoesNotCrash() {
        do {
            let _ = Heap<TrackedElement>.Small<4>(order: .ascending)
        }
    }
}
