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
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [
        // Core: Heap struct (binary min-max heap) + Fixed + Static + Small + Storage + Node + Error
        .target(
            name: "Heap Primitives Core",
            dependencies: [
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ]
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
            dependencies: ["Heap Primitives Core"]
        ),
        // Public: Re-exports all heap modules
        .target(
            name: "Heap Primitives",
            dependencies: [
                "Heap Primitives Core",
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
