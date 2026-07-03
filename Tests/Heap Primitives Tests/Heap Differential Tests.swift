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

// MARK: - Differential test vs a plain-array oracle (template law: adt-tower.md:1247)
//
// The randomized floor every reshaped family ships: a long, mixed, duplicate-laden,
// interleaved push/pop workload with growth across reallocations, checked at every
// extract-min step against a trivially-correct `[Int]` multiset oracle. Deterministic
// (seeded), so a failure reproduces exactly.

/// SplitMix64 — a tiny deterministic `RandomNumberGenerator` (no `SystemRNG`).
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Heap differential (vs array oracle)")
struct HeapDifferentialTests {

    @Test("600 mixed ops: duplicates, interleaved push/pop, growth across reallocations")
    func differentialAgainstArrayOracle() {
        var rng = SplitMix64(seed: 0x5EED_1234_ABCD_0001)
        var heap = Heap<Int>()          // default capacity -> repeated growth under the push bias
        var oracle: [Int] = []          // trivially-correct multiset

        let totalOps = 600
        var pushes = 0
        var interleavedPops = 0

        for _ in 0..<totalOps {
            // Push-biased so the heap grows through several reallocations; small value
            // range guarantees many duplicates.
            let doPush = oracle.isEmpty || (Int(rng.next() % 100) < 58)
            if doPush {
                let value = Int(rng.next() % 40)
                heap.push(value)
                oracle.append(value)
                pushes += 1
            } else {
                let expected = oracle.min()!
                oracle.remove(at: oracle.firstIndex(of: expected)!)
                let got = heap.pop()
                #expect(got == expected)   // extract-min matches the oracle at EVERY step
                interleavedPops += 1
            }
        }

        // Drain the remainder: the tower's extract-min sequence must equal the oracle's
        // sorted-order drain.
        oracle.sort()
        var tail: [Int] = []
        while let next = heap.pop() { tail.append(next) }
        #expect(tail == oracle)

        // Over-drain returns nil (the remove-from-empty convention).
        let overDrain = heap.pop()
        #expect(overDrain == nil)

        // Shape sanity: the workload actually exercised both ops and forced growth.
        #expect(pushes + interleavedPops == totalOps)
        #expect(pushes >= 300)             // >> default capacity -> reallocations occurred
        #expect(interleavedPops >= 100)    // genuinely interleaved, not build-then-drain
    }
}
