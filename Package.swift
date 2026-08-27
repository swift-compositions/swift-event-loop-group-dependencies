// swift-tools-version: 6.3.3

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-event-loop-group-dependencies open
// source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the
// swift-event-loop-group-dependencies project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-event-loop-group-dependencies",
    platforms: [
        .macOS("27"),
        .iOS("27"),
        .tvOS("27"),
        .watchOS("27"),
        .visionOS("27"),
    ],
    products: [
        // The NIO event-loop-group × dependencies integration: the process's
        // main event loop group as a dependency value.
        .library(
            name: "Event Loop Group Dependencies",
            targets: ["Event Loop Group Dependencies"]
        ),
        // The live-context binding check. An executable rather than a test
        // target by necessity — see `Boot Check/main.swift`.
        .executable(
            name: "event-loop-group-boot-check",
            targets: ["Event Loop Group Boot Check"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-compositions/swift-dependencies.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "Event Loop Group Dependencies",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .executableTarget(
            name: "Event Loop Group Boot Check",
            dependencies: [
                "Event Loop Group Dependencies",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "Event Loop Group Dependencies Tests",
            dependencies: [
                "Event Loop Group Dependencies",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Dependencies Test Support", package: "swift-dependencies"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
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
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
