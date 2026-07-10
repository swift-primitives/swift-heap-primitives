// swift-tools-version: 6.3.3

import PackageDescription

// Nested benchmark package (io-bench shape, [BENCH-001] primitives row).
// NOT a test package: benchmarks are executable targets run via
// `swift run -c release` — never `swift test` (arc-bench discipline; the
// io-bench hang precedent). Measurement is release-only by invocation.
//
// Authored as part of the ADT-tower W2 heap dispatch (§9.5 gate item: "Benchmarks/
// packages for heap and slab are AUTHORED as part of their W2 dispatches"). The
// harness is the baselines-doc microprobe methodology (Bench.swift / Bench.Result.swift
// are the array family's generic core, copied verbatim). 6.3.3 label of record:
// "Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), XcodeDefault (Xcode 26.6 17F113)".
let package = Package(
    name: "heap-bench",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Heap Benchmarks",
            dependencies: [
                .product(name: "Heap Primitives", package: "swift-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
            ],
            path: "Heap Benchmarks"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
