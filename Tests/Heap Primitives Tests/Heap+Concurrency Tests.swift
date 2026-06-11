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

// W3 rider — HEAP's own composition under concurrency (arc-1,
// GOAL-tower-arc-shared-soundness §W3): the A-1 reshape (`922322f`) stores the
// `Shared` column behind 28 gate-first sites; the rider's focus is PRIORITY
// ORDER — the sift machinery must stay correct when siblings detach off a
// shared box mid-storm. Models are sorted reference arrays (ascending heap:
// pop == running minimum).
//
// Sendable note: `Heap.swift:369` / `:392` spell `Element: Sendable` bare —
// the same implicit-Copyable clause shape as W2-F1's storage tier and stack's
// `Stack.swift:191` (third A-1 instance; systematic). Copyable-element heaps
// only in this fan-out; recorded for the aggregated W3 report, not baked.

@Suite("Heap concurrency (W3 rider)")
struct HeapConcurrencyTests {

    @Test(arguments: [2, 8, 24])
    func `concurrent push-detach: every sibling heap pops its model in order`(width: Int) async {
        var proto = Heap<Int>(order: .ascending)
        for v in [50, 30, 70, 10, 60] { proto.push(v) }
        let frozen = proto
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for t in 0..<width {
                group.addTask {
                    var mine = frozen                    // sibling: shares the column's box
                    for k in 0..<40 { mine.push(t &* 1000 &+ 100 &+ k) }
                    var model = [50, 30, 70, 10, 60]
                    for k in 0..<40 { model.append(t &* 1000 &+ 100 &+ k) }
                    model.sort()
                    var good = true
                    for want in model {
                        let got = try? mine.pop()
                        good = good && (got == want)
                    }
                    return good && mine.isEmpty
                }
            }
            var out: [Bool] = []
            for await ok in group { out.append(ok) }
            return out
        }
        #expect(outcomes.count == width)
        #expect(outcomes.allSatisfy { $0 })
        let sourceTop = proto.peek
        #expect(sourceTop == 10)                         // the source heap never moved
        let sourceCount = Int(proto.count.underlying.rawValue)
        #expect(sourceCount == 5)
    }

    @Test(arguments: [4, 12])
    func `interleaved push-pop churn matches the running minimum model`(width: Int) async {
        var proto = Heap<Int>(order: .ascending)
        for v in [40, 20, 90] { proto.push(v) }
        let frozen = proto
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for t in 0..<width {
                group.addTask {
                    var mine = frozen
                    var model = [20, 40, 90]             // kept sorted: model[0] == running min
                    var good = true
                    for k in 0..<150 {
                        if k % 3 != 2 {
                            let value = t &* 10_000 &+ k
                            mine.push(value)
                            model.append(value)
                            model.sort()
                        } else if !model.isEmpty {
                            let got = try? mine.pop()
                            let want = model.removeFirst()
                            good = good && (got == want)
                        }
                        good = good && (mine.peek == model.first)
                    }
                    return good
                }
            }
            var out: [Bool] = []
            for await ok in group { out.append(ok) }
            return out
        }
        #expect(outcomes.count == width)
        #expect(outcomes.allSatisfy { $0 })
    }

    @Test
    func `readers hold the seed top while writers detach and churn`() async {
        var proto = Heap<Int>(order: .ascending)
        for v in [5, 3, 9, 1] { proto.push(v) }
        let frozen = proto
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<8 {
                group.addTask {                          // readers: never mutate their sibling
                    let mine = frozen
                    var good = true
                    for _ in 0..<250 {
                        good = good && (mine.peek == 1) && !mine.isEmpty
                    }
                    return good
                }
            }
            for t in 0..<8 {
                group.addTask {                          // writers: detach then drain ordered
                    var mine = frozen
                    mine.push(t &- 100)                  // new global min on MY box only
                    let got = try? mine.pop()
                    return got == t &- 100
                }
            }
            var out: [Bool] = []
            for await ok in group { out.append(ok) }
            return out
        }
        #expect(outcomes.count == 16)
        #expect(outcomes.allSatisfy { $0 })
        let sourceTop = proto.peek
        #expect(sourceTop == 1)
    }
}

@Suite("Heap.Fixed concurrency (W3 rider)")
struct HeapFixedConcurrencyTests {

    @Test
    func `fixed siblings detach with capacity preserved and order intact`() async throws {
        var proto = try Heap<Int>.Fixed(capacity: 16, order: .ascending)
        proto.push(30)
        proto.push(10)
        proto.push(20)
        let frozen = proto
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for t in 0..<8 {
                group.addTask {
                    var mine = frozen                    // sibling of the FIXED column
                    for k in 0..<8 { mine.push(t &* 100 &+ 40 &+ k) }
                    var model = [10, 20, 30]
                    for k in 0..<8 { model.append(t &* 100 &+ 40 &+ k) }
                    model.sort()
                    let capacityHeld = (mine.capacity.underlying.rawValue == frozen.capacity.underlying.rawValue)
                    var good = true
                    for want in model {
                        let got = try? mine.pop()
                        good = good && (got == want)
                    }
                    return good && capacityHeld && mine.isEmpty
                }
            }
            var out: [Bool] = []
            for await ok in group { out.append(ok) }
            return out
        }
        #expect(outcomes.count == 8)
        #expect(outcomes.allSatisfy { $0 })
        let sourceTop = proto.peek
        #expect(sourceTop == 10)
        let sourceCount = Int(proto.count.underlying.rawValue)
        #expect(sourceCount == 3)
    }
}
