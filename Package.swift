// swift-tools-version: 6.2

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
        .library(
            name: "Heap Primitives",
            targets: ["Heap Primitives"]
        ),
        .library(
            name: "Heap Primitives Core",
            targets: ["Heap Primitives Core"]
        ),
        .library(
            name: "Heap Fixed Primitives",
            targets: ["Heap Fixed Primitives"]
        ),
        .library(
            name: "Heap Static Primitives",
            targets: ["Heap Static Primitives"]
        ),
        .library(
            name: "Heap Small Primitives",
            targets: ["Heap Small Primitives"]
        ),
        .library(
            name: "Heap Min Primitives",
            targets: ["Heap Min Primitives"]
        ),
        .library(
            name: "Heap Max Primitives",
            targets: ["Heap Max Primitives"]
        ),
        .library(
            name: "Heap MinMax Primitives",
            targets: ["Heap MinMax Primitives"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-comparison-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-pointer-primitives"),
        .package(path: "../swift-range-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-sequence-primitives"),
    ],
    targets: [
        // Core: Heap struct (binary min-max heap) + Fixed + Static + Small + Storage + Node + Error
        .target(
            name: "Heap Primitives Core",
            dependencies: [
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Pointer Primitives", package: "swift-pointer-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Per-variant modules: Swift.Sequence conformances (Element: Copyable)
        // Separate modules to avoid constraint poisoning on Core types
        .target(
            name: "Heap Fixed Primitives",
            dependencies: ["Heap Primitives Core"]
        ),
        .target(
            name: "Heap Static Primitives",
            dependencies: ["Heap Primitives Core"]
        ),
        .target(
            name: "Heap Small Primitives",
            dependencies: ["Heap Primitives Core"]
        ),
        // Stub modules for future heap variants
        .target(
            name: "Heap Min Primitives",
            dependencies: ["Heap Primitives Core"]
        ),
        .target(
            name: "Heap Max Primitives",
            dependencies: ["Heap Primitives Core"]
        ),
        .target(
            name: "Heap MinMax Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Public: Re-exports all heap modules
        .target(
            name: "Heap Primitives",
            dependencies: [
                "Heap Primitives Core",
                "Heap Fixed Primitives",
                "Heap Static Primitives",
                "Heap Small Primitives",
                "Heap Min Primitives",
                "Heap Max Primitives",
                "Heap MinMax Primitives",
            ]
        ),
        .testTarget(
            name: "Heap Primitives Tests",
            dependencies: ["Heap Primitives"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
