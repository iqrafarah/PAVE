// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PAVECore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "PAVECore", targets: ["PAVECore"]),
    ],
    targets: [
        .target(name: "PAVECore"),
        .testTarget(name: "PAVECoreTests", dependencies: ["PAVECore"]),
    ]
)
