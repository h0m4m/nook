// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nook",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "Nook", targets: ["Nook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "Nook",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Nook",
            resources: [
                .process("Resources/Fonts"),
            ]
        ),
    ]
)
