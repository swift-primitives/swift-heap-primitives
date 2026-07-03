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

/// Family-tier proving benchmark for swift-heap-primitives (ADT-tower W2).
///
/// MEASUREMENT DISCIPLINE (§9.5 + [BENCH-002]): run release-only via
/// `rm -rf .build && swift run -c release "Heap Benchmarks"` — never via
/// `swift test` (the io-bench process-hang precedent). Machine identity,
/// toolchain, and run conditions are recorded by the runner shell and the
/// baselines doc, not introspected here (the primitives tier is
/// Foundation-free, [PRIM-FOUND-001]).
///
/// 6.3.3 label of record:
/// "Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), XcodeDefault (Xcode 26.6 17F113)".
@main
enum Main {
    static func main() {
        print("=== swift-heap-primitives — family-tier proving benchmark (ADT-tower W2) ===")
        print("label of record: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), XcodeDefault (Xcode 26.6 17F113)")
        print("config: sizes=\(Bench.sizes) samples=\(Bench.samples) warmup=\(Bench.warmup)")
        print("targets/sample: structure=\(Bench.structureOpsTarget)")
        print("subjects: tower.direct=Heap<Int> (direct move-only column) · stdlib=Swift.Array binary min-heap")
        print("shapes: insert.zero (heapify-by-insertion) · drain.cycle (build + extract-min to empty)")
        print("")
        Bench.globalWarmup()

        var results: [Bench.Result] = []
        for result in Bench.heapCases() {
            print(result.record)
            results.append(result)
        }

        print("")
        print(summaryTable(results))
        Bench.flushSink()
    }

    /// Aligned median (cv%) table: one row per shape × scale, one column per subject.
    static func summaryTable(_ results: [Bench.Result]) -> String {
        let subjects = ["tower.direct", "stdlib"]
        var rowKeys: [String] = []
        var cells: [String: [String: String]] = [:]
        for r in results {
            let key = "\(r.name) n=\(r.n)"
            if cells[key] == nil {
                rowKeys.append(key)
                cells[key] = [:]
            }
            cells[key]![r.subject] = "\(Bench.fixed(r.median, 3)) (\(Bench.fixed(r.cvPercent, 1))%)"
        }

        let nameWidth = rowKeys.map(\.count).max() ?? 0
        let columnWidth = 22
        var lines: [String] = []
        lines.append(pad("shape", nameWidth) + subjects.map { pad($0, columnWidth) }.joined())
        lines.append(String(repeating: "-", count: nameWidth + columnWidth * subjects.count))
        for key in rowKeys {
            let row = subjects.map { pad(cells[key]?[$0] ?? "-", columnWidth) }.joined()
            lines.append(pad(key, nameWidth) + row)
        }
        lines.append("")
        lines.append("unit: ns/op, median across \(Bench.samples) samples (cv%); per-op = batch / opsPerBatch")
        lines.append("insert.zero: one op = one push · drain.cycle: one op = one push+pop element lifecycle")
        lines.append("extract-min cost ≈ drain.cycle − insert.zero")
        lines.append("NOTE: the insert tax vs stdlib (~1.3–1.9×) is attributable to BOTH (a) the")
        lines.append("      typed-slot append path (count-ledger + initialize seam) AND (b) exchange-")
        lines.append("      based sifting — each swap is move+move+initialize+initialize, ~2× the seam")
        lines.append("      traffic of a classical hole-shift sift. Hole-shift is a LEDGERED measured")
        lines.append("      follow-up (not this wave). extract-min is at parity with stdlib at scale,")
        lines.append("      confirming the seam ops fully specialize (0 witness_method).")
        return lines.joined(separator: "\n")
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
