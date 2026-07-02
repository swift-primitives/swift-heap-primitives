// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-heap-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        // MARK: - Base (ADT-tower W2 shape: carrier `__Heap<S>` + front door `Heap<E>`)
        .library(name: "Heap Primitive", targets: ["Heap Primitive"]),
        .library(name: "Heap Primitives", targets: ["Heap Primitives"]),

        // MARK: - Test Support
        .library(name: "Heap Primitives Test Support", targets: ["Heap Primitives Test Support"]),

        // NOTE (ADT-tower W2, 2026-07-02): the Min / Max single-ended stub targets are
        // DELETED (non-functional `fatalError` placeholders; min IS the canonical `Heap`).
        // `Heap.MinMax` is PARKED under "Experiments/Heap MinMax (parked)/" as a future
        // sibling for the heap-template round (retained in-tree, out of the build graph —
        // see that directory's README.md).
    ],
    dependencies: [
        // Carrier + front door (Heap Primitive):
        .package(url: "https://github.com/swift-primitives/swift-comparison-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        // Test support:
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Carrier + front door (the ADT-tower W2 core)
        .target(
            name: "Heap Primitive",
            dependencies: [
                // Seams (D3): the generic mutate + observability surfaces the ops ride.
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                // Column vocabulary: the default direct heap-allocated linear column.
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                // Allocation-generic growth pin ([DS-029] form-2: `Resource: Memory.Growable`).
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                // Element ordering + typed slots.
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Umbrella ([MOD-005]): re-exports the carrier module.
        .target(
            name: "Heap Primitives",
            dependencies: [
                "Heap Primitive",
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Heap Primitives Tests",
            dependencies: [
                "Heap Primitives",
                "Heap Primitives Test Support",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Heap Primitives Test Support",
            dependencies: [
                "Heap Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Collection Primitives Test Support", package: "swift-collection-primitives"),
                .product(name: "Input Primitives Test Support", package: "swift-input-primitives"),
                .product(name: "Sequence Primitives Test Support", package: "swift-sequence-primitives"),
            ],
            path: "Tests/Support"
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
