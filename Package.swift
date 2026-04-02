// swift-tools-version: 6.3

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
            name: "Heap Binary Primitives",
            targets: ["Heap Binary Primitives"]
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
        .library(
            name: "Heap Primitives Test Support",
            targets: ["Heap Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-comparison-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-sequence-primitives"),
    ],
    targets: [

        // MARK: - Core
        .target(
            name: "Heap Primitives Core",
            dependencies: [
                .product(name: "Comparison Primitives", package: "swift-comparison-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Small Primitives", package: "swift-buffer-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Binary
        .target(
            name: "Heap Binary Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Fixed
        .target(
            name: "Heap Fixed Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Static
        .target(
            name: "Heap Static Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Small
        .target(
            name: "Heap Small Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Min
        .target(
            name: "Heap Min Primitives",
            dependencies: ["Heap Primitives Core"]
        ),

        // MARK: - Max
        .target(
            name: "Heap Max Primitives",
            dependencies: ["Heap Primitives Core"]
        ),

        // MARK: - MinMax
        .target(
            name: "Heap MinMax Primitives",
            dependencies: [
                "Heap Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Heap Primitives",
            dependencies: [
                "Heap Primitives Core",
                "Heap Binary Primitives",
                "Heap Fixed Primitives",
                "Heap Static Primitives",
                "Heap Small Primitives",
                "Heap Min Primitives",
                "Heap Max Primitives",
                "Heap MinMax Primitives",
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "Heap Primitives Tests",
            dependencies: [
                "Heap Primitives",
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
