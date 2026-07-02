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

import Heap_Primitives

// The single ratified column: the canonical `Heap<E>` front door rides the DIRECT,
// heap-allocated contiguous linear column (move-only). No `Shared` (CoW) column is
// pulled (no live consumer), so the heap family has one tower subject: `tower.direct`.
//
// `stdlib` is a hand-written binary min-heap over `Swift.Array<Int>` — the honest
// reference, since the standard library ships no heap. Both implement the identical
// binary-min algorithm; the delta is the tower's typed-slot seam machinery vs stdlib's
// `Array` subscript + CoW.

typealias TowerHeap = Heap<Int>

/// A textbook binary min-heap over `Swift.Array` — the `stdlib` reference subject.
struct StdMinHeap {
    var storage: [Int] = []

    var isEmpty: Bool { storage.isEmpty }
    var count: Int { storage.count }
    var min: Int { storage[0] }

    mutating func push(_ value: Int) {
        storage.append(value)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            if storage[child] < storage[parent] {
                storage.swapAt(child, parent)
                child = parent
            } else { break }
        }
    }

    mutating func pop() -> Int {
        let n = storage.count
        if n == 1 { return storage.removeLast() }
        let root = storage[0]
        storage[0] = storage.removeLast()
        var parent = 0
        let m = storage.count
        while true {
            let l = 2 * parent + 1
            let r = l + 1
            var smallest = parent
            if l < m, storage[l] < storage[smallest] { smallest = l }
            if r < m, storage[r] < storage[smallest] { smallest = r }
            if smallest == parent { break }
            storage.swapAt(parent, smallest)
            parent = smallest
        }
        return root
    }
}
