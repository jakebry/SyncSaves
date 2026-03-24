// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SyncSaves",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SyncSavesCore",
            targets: ["SyncSavesCore"]),
        .executable(
            name: "SyncSaves",
            targets: ["SyncSaves"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SyncSavesCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]),
        .executableTarget(
            name: "SyncSaves",
            dependencies: ["SyncSavesCore"]),
        .testTarget(
            name: "SyncSavesTests",
            dependencies: ["SyncSavesCore"]),
    ]
)