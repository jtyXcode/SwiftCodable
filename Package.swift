// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SwiftCodable",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
        .tvOS(.v12),
        .watchOS(.v5)
    ],
    products: [
        .library(
            name: "SwiftCodable",
            targets: ["SwiftCodable"]
        ),
        .executable(
            name: "SwiftCodableDemo",
            targets: ["SwiftCodableDemo"]
        )
    ],
    targets: [
        .target(
            name: "SwiftCodable",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SwiftCodableDemo",
            dependencies: ["SwiftCodable"]
        ),
        .testTarget(
            name: "SwiftCodableTests",
            dependencies: ["SwiftCodable"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
