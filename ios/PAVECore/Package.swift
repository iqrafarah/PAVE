// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PAVECore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "PAVECore", targets: ["PAVECore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.55.0"),
    ],
    targets: [
        .target(
            name: "PAVECore",
            dependencies: [
                .product(name: "Auth", package: "supabase-swift"),
            ]
        ),
        .testTarget(
            name: "PAVECoreTests",
            dependencies: [
                "PAVECore",
                .product(name: "Auth", package: "supabase-swift"),
            ]
        ),
    ]
)
