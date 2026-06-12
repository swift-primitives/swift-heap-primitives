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
// Sendable note (finding W3-F1, FIXED): `Heap.swift`'s two Sendable clauses
// originally spelled `Element: Sendable` bare — implicitly `Copyable` — the
// same clause shape as W2-F1's storage tier and stack's (third A-1 instance;
// REPORT-arc-shared-soundness-W3 §1). The `~Copyable` suppression landed with
// the principal-ratified clause pass; the regression lock lives in
// `HeapSendableSurfaceTests` below. The CONCURRENCY suites still fan out
// Copyable-element heaps only — siblings are copies, which is structural, not
// the finding.

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

// MARK: - Sendable surface (the W3-F1 regression lock)

/// Move-only Sendable element satisfying the heap's `Comparison.Protocol`
/// bound (the `UniqueResource` fixture shape) — the
/// previously-excluded instantiation, live since the clause fix (W3-F1,
/// REPORT-arc-shared-soundness-W3 §1).
private struct MoveOnlyProbe: ~Copyable, Sendable, Comparison_Primitives.Comparison.`Protocol` {
    let id: Int
    init(_ id: Int) { self.id = id }
    static func < (lhs: borrowing MoveOnlyProbe, rhs: borrowing MoveOnlyProbe) -> Bool {
        lhs.id < rhs.id
    }
    static func == (lhs: borrowing MoveOnlyProbe, rhs: borrowing MoveOnlyProbe) -> Bool {
        lhs.id == rhs.id
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}

@Suite("Heap Sendable surface (W3-F1 regression)")
struct HeapSendableSurfaceTests {

    @Test
    func `sendable admits move-only elements on Heap (W3-F1 regression)`() {
        var moveOnly = Heap<MoveOnlyProbe>(order: .ascending)
        moveOnly.push(MoveOnlyProbe(7))
        // The conformances are declared `@unsafe` (their strip is the deferred
        // [MEM-SAFE-024] sweep), so the use sites carry the marker.
        unsafe requireSendable(moveOnly)


        let copyable = Heap<Int>(order: .ascending)
        unsafe requireSendable(copyable)

        let top = moveOnly.withPriority { $0.id }
        #expect(top == 7)
    }
}
