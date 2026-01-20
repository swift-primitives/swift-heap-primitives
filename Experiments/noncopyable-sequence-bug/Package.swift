// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "noncopyable-sequence-bug",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "noncopyable-sequence-bug",
            targets: ["noncopyable-sequence-bug"]
        )
    ],
    targets: [
        .target(
            name: "noncopyable-sequence-bug",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
    ]
)
