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
        // MARK: - Base
        .library(name: "Heap Primitive", targets: ["Heap Primitive"]),
        .library(name: "Heap Primitives", targets: ["Heap Primitives"]),
        // MARK: - Min variant
        .library(name: "Heap Min Primitive", targets: ["Heap Min Primitive"]),
        .library(name: "Heap Min Primitives", targets: ["Heap Min Primitives"]),
        
        // MARK: - Max variant
        .library(name: "Heap Max Primitive", targets: ["Heap Max Primitive"]),
        .library(name: "Heap Max Primitives", targets: ["Heap Max Primitives"]),
        
        // MARK: - MinMax variant
        .library(name: "Heap MinMax Primitive", targets: ["Heap MinMax Primitive"]),
        .library(name: "Heap MinMax Primitives", targets: ["Heap MinMax Primitives"]),
        
        // MARK: - Test Support
        .library(name: "Heap Primitives Test Support", targets: ["Heap Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-comparison-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-column-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
    ],
    targets: [
        
        // MARK: - Base type (Heap dynamic/growable + Index / Navigate)
        .target(
            name: "Heap Primitive",
            dependencies: [
                .product(name: "Column Primitives", package: "swift-column-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        
        
        // MARK: - Static type
        
        // MARK: - Small type
        
        // MARK: - Min type (stub)
            .target(
                name: "Heap Min Primitive",
                dependencies: [
                    "Heap Primitive",
                    .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                ]
            ),
        
        // MARK: - Max type (stub)
        .target(
            name: "Heap Max Primitive",
            dependencies: [
                "Heap Primitive",
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
            ]
        ),
        
        // MARK: - MinMax type
        // ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
        // (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
        // full template round.
            .target(
                name: "Heap MinMax Primitive",
                dependencies: [
                    "Heap Primitive",
                    .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                    .product(name: "Index Primitives", package: "swift-index-primitives"),
                    .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                    .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                    .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                    .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                    .product(name: "Buffer Linear Bounded Primitive", package: "swift-buffer-linear-primitives"),
                    // Cleave-3 #12a/#5a: Heap.Small / Heap.MinMax.Small compose Buffer<Storage<E>.Small<n>>.Linear.
                    .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                    .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                    .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                    .product(name: "Property Primitives", package: "swift-property-primitives"),
                ]
            ),
        
        
        // MARK: - Static ops
        
        // MARK: - Small ops
        
        // MARK: - Min ops (stub conformances)
            .target(
                name: "Heap Min Primitives",
                dependencies: [
                    "Heap Min Primitive",
                    "Heap Primitive",
                    .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                ]
            ),
        
        // MARK: - Max ops (stub conformances)
        .target(
            name: "Heap Max Primitives",
            dependencies: [
                "Heap Max Primitive",
                "Heap Primitive",
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
            ]
        ),
        
        // MARK: - MinMax ops
        // ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
        // (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at heap's
        // full template round.
            .target(
                name: "Heap MinMax Primitives",
                dependencies: [
                    "Heap MinMax Primitive",
                    "Heap Primitive",
                    .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                    .product(name: "Index Primitives", package: "swift-index-primitives"),
                    .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                    .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                    .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                    .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                    .product(name: "Buffer Linear Bounded Primitive", package: "swift-buffer-linear-primitives"),
                    // Cleave-3 #12a/#5a: Heap.Small / Heap.MinMax.Small compose Buffer<Storage<E>.Small<n>>.Linear.
                    .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                    .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                    .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                    .product(name: "Iterable", package: "swift-iterator-primitives"),
                    .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                    .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                    .product(name: "Property Primitives", package: "swift-property-primitives"),
                ]
            ),
        
        // MARK: - Base ops + Umbrella ([MOD-005] dual-role: base conformances + re-export of all variants)
        .target(
            name: "Heap Primitives",
            dependencies: [
                "Heap Primitive",
                "Heap Min Primitives",
                "Heap Max Primitives",
                // ⚠️ W5 QUARANTINE (2026-06-11): MinMax parks with memory-small
                // (pre-W1 Memory.Inline<E,n>) per the W5-5 ruling; restores at
                // heap's full template round.
                "Heap MinMax Primitive",
                "Heap MinMax Primitives",
                .product(name: "Column Primitives", package: "swift-column-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
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
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
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
