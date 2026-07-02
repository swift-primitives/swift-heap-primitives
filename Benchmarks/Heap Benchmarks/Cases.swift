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
import Index_Primitives

extension Bench {

    /// The heap family's hot ops (§9.5): insert, extract-min, heapify.
    ///
    /// The tower `Heap` is move-only, so a persistent subject cannot be copied to reset
    /// between reps — every rep builds fresh. Two shapes isolate the costs:
    ///
    /// - `insert.zero`: n pushes from empty (heapify-by-insertion; growth included).
    ///   One op = one `push` (`opsPerBatch = reps * n`).
    /// - `drain.cycle`: n pushes THEN n extract-mins (each pop restores the invariant
    ///   via siftDown). One op = one push+pop element lifecycle
    ///   (`opsPerBatch = reps * n`); the extract-min cost is `drain.cycle - insert.zero`.
    ///
    /// `peek` is folded in as an observed `min` read after the build (an O(1) borrow).
    static func heapCases() -> [Result] {
        var results: [Result] = []
        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let ops = reps * n
            let seed = opaque(1)

            // Pre-generated workload: a fixed, checked-in permutation-ish stream
            // (descending-ish keys so nearly every insert sifts toward the root).
            let values: [Int] = (0..<n).map { (n - $0) &* 2654435761 & 0x7fff_ffff }

            // MARK: insert.zero (heapify-by-insertion)

            results.append(Result(
                name: "insert.zero", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var h = TowerHeap()
                        for v in values { h.push(v &+ seed) }
                        let peek = h.min
                        acc &+= peek
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var h = StdMinHeap()
                        for v in values { h.push(v &+ seed) }
                        acc &+= h.min
                    }
                    sink(acc)
                }
            ))

            // MARK: drain.cycle (build then extract-min to empty)

            results.append(Result(
                name: "drain.cycle", subject: "tower.direct", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var h = TowerHeap()
                        for v in values { h.push(v &+ seed) }
                        while !h.isEmpty { acc &+= h.pop() }
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "drain.cycle", subject: "stdlib", n: n, opsPerBatch: ops,
                perOpNs: sample(opsPerBatch: ops) {
                    var acc = 0
                    for _ in 0..<reps {
                        var h = StdMinHeap()
                        for v in values { h.push(v &+ seed) }
                        while !h.isEmpty { acc &+= h.pop() }
                    }
                    sink(acc)
                }
            ))
        }
        return results
    }
}
